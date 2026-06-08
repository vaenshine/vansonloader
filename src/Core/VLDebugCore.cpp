/**
 * VansonLoader L2.3 - Hardware Watchpoint Engine Implementation
 * ARM64 硬件断点: DBGWVR/DBGWCR 寄存器操作 + Mach Exception 捕获
 */

#include "VLDebugCore.hpp"
#include "VLCore.hpp"
#include <mach/arm/exception.h>
#include <mach/exception_types.h>
#include <mach/mach.h>
#include <mach/mach_types.h>
#include <mach/thread_act.h>
#include <mach/thread_status.h>
#include <dlfcn.h>
#include <sys/time.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cstring>
#include <cstdarg>
#include <dispatch/dispatch.h>

// Async-Signal-Safe 日志: 写到沙盒 Documents/vldebug.log
static int _vlLogFd = -1;
static char _vlLogPath[512] = {0};

// ObjC 层调用此函数设置日志路径 (在 addWatch 之前)
extern "C" void VLDebugSetLogPath(const char *path) {
    if (!path) return;
    snprintf(_vlLogPath, sizeof(_vlLogPath), "%s", path);
    // 如果已经打开了旧 fd，关掉重开
    if (_vlLogFd >= 0) {
        close(_vlLogFd);
        _vlLogFd = -1;
    }
}

static void SafeLog(const char *format, ...) {
    if (_vlLogFd < 0 && _vlLogPath[0] != '\0') {
        _vlLogFd = open(_vlLogPath, O_WRONLY | O_CREAT | O_APPEND, 0666);
    }
    if (_vlLogFd < 0) return;
    
    char buf[512];
    va_list args;
    va_start(args, format);
    int len = vsnprintf(buf, sizeof(buf), format, args);
    va_end(args);
    if (len > 0) {
        write(_vlLogFd, "[VLDebug] ", 10);
        write(_vlLogFd, buf, (size_t)len);
        write(_vlLogFd, "\n", 1);
        fsync(_vlLogFd);
    }
}

namespace vcore {

const std::vector<WatchHit> DebugCore::_emptyHits;

DebugCore &DebugCore::inst() {
    static DebugCore instance;
    return instance;
}

DebugCore::~DebugCore() {
    detach();
}

#pragma mark - Lifecycle

bool DebugCore::attach() {
    std::lock_guard<std::mutex> lock(_mutex);
    return attachLocked();
}

bool DebugCore::probeAvailability() {
    task_t task = mach_task_self();
    if (task == MACH_PORT_NULL) return false;

    mach_port_t probePort = MACH_PORT_NULL;
    kern_return_t kr = mach_port_allocate(task, MACH_PORT_RIGHT_RECEIVE, &probePort);
    if (kr != KERN_SUCCESS) return false;

    kr = mach_port_insert_right(task, probePort, probePort, MACH_MSG_TYPE_MAKE_SEND);
    if (kr != KERN_SUCCESS) {
        mach_port_deallocate(task, probePort);
        return false;
    }

    exception_mask_t masks[EXC_TYPES_COUNT]{};
    exception_handler_t oldHandlers[EXC_TYPES_COUNT]{};
    exception_behavior_t oldBehaviors[EXC_TYPES_COUNT]{};
    thread_state_flavor_t oldFlavors[EXC_TYPES_COUNT]{};
    mach_msg_type_number_t oldCount = EXC_TYPES_COUNT;

    kr = task_swap_exception_ports(task,
                                   EXC_MASK_BREAKPOINT,
                                   probePort,
                                   (exception_behavior_t)(EXCEPTION_DEFAULT | MACH_EXCEPTION_CODES),
                                   ARM_THREAD_STATE64,
                                   masks,
                                   &oldCount,
                                   oldHandlers,
                                   oldBehaviors,
                                   oldFlavors);

    bool exceptionOK = (kr == KERN_SUCCESS);
    if (exceptionOK) {
        if (oldCount == 0) {
            task_set_exception_ports(task,
                                     EXC_MASK_BREAKPOINT,
                                     MACH_PORT_NULL,
                                     EXCEPTION_DEFAULT,
                                     ARM_THREAD_STATE64);
        }
        for (mach_msg_type_number_t i = 0; i < oldCount; i++) {
            task_set_exception_ports(task,
                                     masks[i],
                                     oldHandlers[i],
                                     oldBehaviors[i],
                                     oldFlavors[i]);
            if (oldHandlers[i] != MACH_PORT_NULL) {
                mach_port_deallocate(task, oldHandlers[i]);
            }
        }
    }

    mach_port_deallocate(task, probePort);
    if (!exceptionOK) return false;

    thread_act_array_t threads = nullptr;
    mach_msg_type_number_t threadCount = 0;
    kr = task_threads(task, &threads, &threadCount);
    if (kr != KERN_SUCCESS || threadCount == 0) return false;

    bool debugStateOK = false;
    for (mach_msg_type_number_t t = 0; t < threadCount; t++) {
        arm_debug_state64_t dbgState{};
        mach_msg_type_number_t dbgCount = ARM_DEBUG_STATE64_COUNT;

        kr = thread_get_state(threads[t], ARM_DEBUG_STATE64,
                              (thread_state_t)&dbgState, &dbgCount);
        if (kr != KERN_SUCCESS) continue;

        kr = thread_set_state(threads[t], ARM_DEBUG_STATE64,
                              (thread_state_t)&dbgState, ARM_DEBUG_STATE64_COUNT);
        if (kr == KERN_SUCCESS) {
            debugStateOK = true;
            break;
        }
    }

    for (mach_msg_type_number_t t = 0; t < threadCount; t++) {
        mach_port_deallocate(task, threads[t]);
    }
    vm_deallocate(task, (vm_address_t)threads, threadCount * sizeof(thread_act_t));

    return debugStateOK;
}

// 内部版本，调用者必须已持有 _mutex
bool DebugCore::attachLocked() {
    if (_attached) return true;
    
    _task = mach_task_self();
    if (_task == MACH_PORT_NULL) return false;
    
    _slots.clear();
    for (uint32_t i = 0; i < MAX_SLOTS; i++) {
        WatchSlot slot{};
        slot.index = i;
        slot.active = false;
        _slots.push_back(slot);
    }
    
    if (!setupExceptionPort()) {
        _task = MACH_PORT_NULL;
        return false;
    }
    
    _attached = true;
    return true;
}

void DebugCore::detach() {
    _listening = false;
    
    if (_attached) {
        std::lock_guard<std::mutex> lock(_mutex);
        for (auto &slot : _slots) {
            if (slot.active) {
                clearHardware(slot.index);
                slot.active = false;
            }
        }
        _attached = false;
    }
    
    // 发送空消息唤醒监听线程
    if (_exceptionPort != MACH_PORT_NULL) {
        mach_msg_header_t msg{};
        msg.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_MAKE_SEND, 0);
        msg.msgh_size = sizeof(msg);
        msg.msgh_remote_port = _exceptionPort;
        msg.msgh_local_port = MACH_PORT_NULL;
        mach_msg(&msg, MACH_SEND_MSG | MACH_SEND_TIMEOUT, sizeof(msg), 0,
                 MACH_PORT_NULL, 100, MACH_PORT_NULL);
    }
    
    if (_listenerThread.joinable()) {
        _listenerThread.join();
    }
    
    if (_exceptionPort != MACH_PORT_NULL) {
        mach_port_deallocate(mach_task_self(), _exceptionPort);
        _exceptionPort = MACH_PORT_NULL;
    }
    
    _task = MACH_PORT_NULL;
}

#pragma mark - Exception Port

bool DebugCore::setupExceptionPort() {
    kern_return_t kr;
    
    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &_exceptionPort);
    if (kr != KERN_SUCCESS) return false;
    
    kr = mach_port_insert_right(mach_task_self(), _exceptionPort, _exceptionPort,
                                 MACH_MSG_TYPE_MAKE_SEND);
    if (kr != KERN_SUCCESS) {
        mach_port_deallocate(mach_task_self(), _exceptionPort);
        _exceptionPort = MACH_PORT_NULL;
        return false;
    }
    
    kr = task_set_exception_ports(_task, EXC_MASK_BREAKPOINT,
                                  _exceptionPort,
                                  (exception_behavior_t)(EXCEPTION_DEFAULT |
                                                         MACH_EXCEPTION_CODES),
                                  ARM_THREAD_STATE64);
    if (kr != KERN_SUCCESS) {
        mach_port_deallocate(mach_task_self(), _exceptionPort);
        _exceptionPort = MACH_PORT_NULL;
        return false;
    }
    
    _listening = true;
    _listenerThread = std::thread(&DebugCore::listenerThread, this);
    return true;
}

#pragma mark - Exception Listener

// Mach exception message structures for EXCEPTION_DEFAULT (non-complex)
#pragma pack(push, 4)
struct ExceptionMsg {
    mach_msg_header_t head;
    mach_msg_body_t body;
    mach_msg_port_descriptor_t thread;
    mach_msg_port_descriptor_t task;
    NDR_record_t NDR;
    exception_type_t exception;
    mach_msg_type_number_t codeCnt;
    mach_exception_data_type_t code[2];
    // 预留 trailer 空间
    mach_msg_trailer_t trailer;
    char _pad[256];
};

struct ExceptionReply {
    mach_msg_header_t head;
    NDR_record_t NDR;
    kern_return_t retCode;
};
#pragma pack(pop)

void DebugCore::listenerThread() {
    while (_listening) {
        ExceptionMsg msg{};
        kern_return_t kr = mach_msg(&msg.head, MACH_RCV_MSG | MACH_RCV_LARGE,
                                     0, sizeof(msg), _exceptionPort,
                                     MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
        
        if (kr != KERN_SUCCESS) {
            SafeLog("mach_msg recv failed: %d (0x%X)", kr, kr);
            if (!_listening) break;
            usleep(100000);
            continue;
        }
        
        if (msg.exception == EXC_BREAKPOINT) {
            mach_port_t excThread = msg.thread.name;
            
            // Phase 1: 收集数据 (纯 mach API，栈上分配，零 malloc)
            arm_thread_state64_t threadState{};
            mach_msg_type_number_t tsCount = ARM_THREAD_STATE64_COUNT;
            thread_get_state(excThread, ARM_THREAD_STATE64,
                             (thread_state_t)&threadState, &tsCount);
            
            uint64_t pc = arm_thread_state64_get_pc(threadState);
            uint64_t lr = arm_thread_state64_get_lr(threadState);
            
            // 找到触发的 watchpoint 槽位
            arm_debug_state64_t dbgState{};
            mach_msg_type_number_t dbgCount = ARM_DEBUG_STATE64_COUNT;
            kern_return_t getKr = thread_get_state(excThread, ARM_DEBUG_STATE64,
                                                    (thread_state_t)&dbgState, &dbgCount);
            
            // 收集原始数据到栈上
            RawHitContext raw{};
            raw.pc = pc;
            raw.lr = lr;
            uint64_t exceptionCode = (msg.codeCnt > 0) ? (uint64_t)msg.code[0] : 0;
            uint64_t exceptionSubcode = (msg.codeCnt > 1) ? (uint64_t)msg.code[1] : 0;
            raw.exceptionCode = exceptionCode;
            raw.exceptionSubcode = exceptionSubcode;
            raw.wpIndex = resolveHitSlot(exceptionCode, exceptionSubcode);
            raw.address = 0;
            
            if (getKr == KERN_SUCCESS) {
                slotAddressForIndex(raw.wpIndex, raw.address);
                
                // Phase 2: 清除所有 watchpoint
                for (int i = 0; i < 16; i++) {
                    if (dbgState.__wcr[i] & 1) {
                        dbgState.__wcr[i] = 0;
                    }
                }
                thread_set_state(excThread, ARM_DEBUG_STATE64,
                                 (thread_state_t)&dbgState, ARM_DEBUG_STATE64_COUNT);
            }
            
            // Phase 3: 回复内核 (让目标线程恢复运行)
            mach_port_t replyPort = msg.head.msgh_remote_port;
            ExceptionReply reply{};
            reply.head.msgh_bits = MACH_MSGH_BITS(MACH_MSGH_BITS_REMOTE(msg.head.msgh_bits), 0);
            reply.head.msgh_remote_port = replyPort;
            reply.head.msgh_local_port = MACH_PORT_NULL;
            reply.head.msgh_size = sizeof(reply);
            reply.head.msgh_id = msg.head.msgh_id + 100;
            reply.NDR = NDR_record;
            reply.retCode = KERN_SUCCESS;
            
            kr = mach_msg(&reply.head, MACH_SEND_MSG, sizeof(reply), 0,
                          MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
            
            if (kr != KERN_SUCCESS) {
                SafeLog("FAILED to send reply: %d", kr);
            } else {
                // Phase 4: 异步处理 (目标线程已恢复，锁已释放，可以安全 malloc)
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    this->safeProcessHit(raw);
                    {
                        std::lock_guard<std::mutex> lock(this->_mutex);
                        for (auto &slot : this->_slots) {
                            if (slot.active) {
                                this->applyToHardware(slot);
                            }
                        }
                    }
                });
            }
            
            continue;
        }
        
        // 非断点异常
        {
            ExceptionReply reply{};
            reply.head.msgh_bits = MACH_MSGH_BITS(MACH_MSGH_BITS_REMOTE(msg.head.msgh_bits), 0);
            reply.head.msgh_remote_port = msg.head.msgh_remote_port;
            reply.head.msgh_local_port = MACH_PORT_NULL;
            reply.head.msgh_size = sizeof(reply);
            reply.head.msgh_id = msg.head.msgh_id + 100;
            reply.NDR = NDR_record;
            reply.retCode = KERN_SUCCESS;
            
            mach_msg(&reply.head, MACH_SEND_MSG, sizeof(reply), 0,
                     MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
        }
    }
    
}

// 暂时保留但不会被调用 (调试版不做异步处理)
void DebugCore::safeProcessHit(RawHitContext raw) {
    if (!slotAddressForIndex(raw.wpIndex, raw.address)) {
        raw.wpIndex = resolveHitSlot(raw.exceptionCode, raw.exceptionSubcode);
        if (!slotAddressForIndex(raw.wpIndex, raw.address)) {
            return;
        }
    }

    WatchHit hit{};
    hit.wpIndex = raw.wpIndex;
    hit.pc = raw.pc;
    hit.lr = raw.lr;
    hit.address = raw.address;
    
    StackFrame pcFrame = symbolicate(raw.pc);
    hit.imageName = pcFrame.imageName;
    hit.offset = pcFrame.offset;
    
    uint64_t val = 0;
    if (raw.wpIndex < MAX_SLOTS && raw.wpIndex < _slots.size()) {
        size_t readSize = 4;
        {
            std::lock_guard<std::mutex> lock(_mutex);
            if (raw.wpIndex < _slots.size()) {
                readSize = byteCountForSize(_slots[raw.wpIndex].size);
            }
        }
        if (MemEngine::inst().readMem(raw.address, &val, readSize)) {
            hit.newValue = val;
            std::lock_guard<std::mutex> lock(_mutex);
            if (raw.wpIndex < _slots.size()) {
                _slots[raw.wpIndex].lastValue = val;
                _slots[raw.wpIndex].lastValueValid = true;
            }
        }
    }
    
    struct timeval tv;
    gettimeofday(&tv, nullptr);
    hit.timestamp = tv.tv_sec + tv.tv_usec / 1000000.0;
    hit.stackTrace = {};
    
    {
        std::lock_guard<std::mutex> lock(_hitMutex);
        if (raw.wpIndex < _slots.size()) {
            _slots[raw.wpIndex].hits.push_back(hit);
        }
    }
    
    WatchHitCallback cb;
    {
        std::lock_guard<std::mutex> lock(_hitMutex);
        cb = _hitCallback;
    }
    if (cb) {
        cb(hit);
    }
}

#pragma mark - Watchpoint Management

int DebugCore::addWatch(uint64_t address, WatchType type, WatchSize size) {
    std::lock_guard<std::mutex> lock(_mutex);
    
    if (!_attached) {
        if (!attachLocked()) {
            return -1;
        }
    }
    
    // 找空闲槽位
    int freeSlot = -1;
    for (uint32_t i = 0; i < MAX_SLOTS; i++) {
        if (!_slots[i].active) {
            freeSlot = (int)i;
            break;
        }
    }
    if (freeSlot < 0) return -1;
    
    _slots[freeSlot].type = type;
    _slots[freeSlot].size = size;
    _slots[freeSlot].address = address;
    _slots[freeSlot].lastValue = 0;
    _slots[freeSlot].lastValueValid = readSlotValueLocked(_slots[freeSlot], _slots[freeSlot].lastValue);
    _slots[freeSlot].active = true;
    _slots[freeSlot].hits.clear();
    
    if (!applyToHardware(_slots[freeSlot])) {
        _slots[freeSlot].active = false;
        _slots[freeSlot].lastValueValid = false;
        return -1;
    }
    
    return freeSlot;
}

bool DebugCore::removeWatch(uint32_t index) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (index >= MAX_SLOTS || !_slots[index].active) return false;
    
    clearHardware(index);
    _slots[index].active = false;
    _slots[index].lastValueValid = false;
    return true;
}

void DebugCore::removeAll() {
    std::lock_guard<std::mutex> lock(_mutex);
    for (auto &slot : _slots) {
        if (slot.active) {
            clearHardware(slot.index);
            slot.active = false;
            slot.lastValueValid = false;
        }
    }
}

uint32_t DebugCore::activeCount() const {
    uint32_t count = 0;
    for (auto &slot : _slots) {
        if (slot.active) count++;
    }
    return count;
}

#pragma mark - Hit Records

const std::vector<WatchHit> &DebugCore::getHits(uint32_t slotIndex) const {
    if (slotIndex < _slots.size()) return _slots[slotIndex].hits;
    return _emptyHits;
}

void DebugCore::clearHits(uint32_t slotIndex) {
    std::lock_guard<std::mutex> lock(_hitMutex);
    if (slotIndex < _slots.size()) {
        _slots[slotIndex].hits.clear();
    }
}

void DebugCore::clearAllHits() {
    std::lock_guard<std::mutex> lock(_hitMutex);
    for (auto &slot : _slots) {
        slot.hits.clear();
    }
}

void DebugCore::setHitCallback(WatchHitCallback cb) {
    std::lock_guard<std::mutex> lock(_hitMutex);
    _hitCallback = cb;
}

#pragma mark - Hardware Operations

bool DebugCore::applyToHardware(const WatchSlot &slot) {
    if (_task == MACH_PORT_NULL) return false;
    
    // 获取主线程
    thread_act_array_t threads;
    mach_msg_type_number_t threadCount;
    if (task_threads(_task, &threads, &threadCount) != KERN_SUCCESS) return false;
    if (threadCount == 0) return false;
    
    bool success = false;
    
    for (mach_msg_type_number_t t = 0; t < threadCount; t++) {
        arm_debug_state64_t dbgState{};
        mach_msg_type_number_t dbgCount = ARM_DEBUG_STATE64_COUNT;
        
        kern_return_t kr = thread_get_state(threads[t], ARM_DEBUG_STATE64,
                                             (thread_state_t)&dbgState, &dbgCount);
        if (kr != KERN_SUCCESS) continue;
        
        // 配置 DBGWVR (地址)
        dbgState.__wvr[slot.index] = slot.address;
        
        // 配置 DBGWCR (控制)
        uint64_t wcr = 0;
        wcr |= 1;  // Enable bit
        
        // LSC: Load/Store Control
        switch (slot.type) {
            case WatchType::Write:     wcr |= (0x2 << 3); break;
            case WatchType::Read:      wcr |= (0x1 << 3); break;
            case WatchType::ReadWrite: wcr |= (0x3 << 3); break;
        }
        
        // BAS: Byte Address Select
        wcr |= ((uint64_t)basForSize(slot.size) << 5);
        
        // PAC: 0 (match in current EL)
        // HMC: 0
        // SSC: 0
        
        dbgState.__wcr[slot.index] = wcr;
        
        kr = thread_set_state(threads[t], ARM_DEBUG_STATE64,
                               (thread_state_t)&dbgState, ARM_DEBUG_STATE64_COUNT);
        if (kr == KERN_SUCCESS && t == 0) success = true;
    }
    
    // 释放线程端口
    for (mach_msg_type_number_t t = 0; t < threadCount; t++) {
        mach_port_deallocate(mach_task_self(), threads[t]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)threads,
                  threadCount * sizeof(thread_act_t));
    
    return success;
}

bool DebugCore::clearHardware(uint32_t index) {
    if (_task == MACH_PORT_NULL || index >= MAX_SLOTS) return false;
    
    thread_act_array_t threads;
    mach_msg_type_number_t threadCount;
    if (task_threads(_task, &threads, &threadCount) != KERN_SUCCESS) return false;
    
    for (mach_msg_type_number_t t = 0; t < threadCount; t++) {
        arm_debug_state64_t dbgState{};
        mach_msg_type_number_t dbgCount = ARM_DEBUG_STATE64_COUNT;
        
        if (thread_get_state(threads[t], ARM_DEBUG_STATE64,
                              (thread_state_t)&dbgState, &dbgCount) == KERN_SUCCESS) {
            dbgState.__wvr[index] = 0;
            dbgState.__wcr[index] = 0;
            thread_set_state(threads[t], ARM_DEBUG_STATE64,
                              (thread_state_t)&dbgState, ARM_DEBUG_STATE64_COUNT);
        }
        mach_port_deallocate(mach_task_self(), threads[t]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)threads,
                  threadCount * sizeof(thread_act_t));
    
    return true;
}

uint8_t DebugCore::basForSize(WatchSize size) {
    switch (size) {
        case WatchSize::Byte1: return 0x01;
        case WatchSize::Byte2: return 0x03;
        case WatchSize::Byte4: return 0x0F;
        case WatchSize::Byte8: return 0xFF;
    }
    return 0x0F;
}

size_t DebugCore::byteCountForSize(WatchSize size) const {
    switch (size) {
        case WatchSize::Byte1: return 1;
        case WatchSize::Byte2: return 2;
        case WatchSize::Byte4: return 4;
        case WatchSize::Byte8: return 8;
    }
    return 4;
}

bool DebugCore::slotContainsAddress(const WatchSlot &slot, uint64_t address) const {
    if (!slot.active || address == 0) return false;
    uint64_t size = byteCountForSize(slot.size);
    return address >= slot.address && address < slot.address + size;
}

bool DebugCore::readSlotValueLocked(const WatchSlot &slot, uint64_t &value) {
    value = 0;
    return MemEngine::inst().readMem(slot.address, &value,
                                    byteCountForSize(slot.size));
}

bool DebugCore::slotAddressForIndex(uint32_t index, uint64_t &address) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (index >= MAX_SLOTS || index >= _slots.size() || !_slots[index].active) {
        return false;
    }
    address = _slots[index].address;
    return true;
}

uint32_t DebugCore::resolveHitSlot(uint64_t exceptionCode,
                                   uint64_t exceptionSubcode) {
    std::lock_guard<std::mutex> lock(_mutex);
    
    for (const auto &slot : _slots) {
        if (slotContainsAddress(slot, exceptionSubcode)) {
            return slot.index;
        }
    }
    
    for (const auto &slot : _slots) {
        if (slotContainsAddress(slot, exceptionCode)) {
            return slot.index;
        }
    }
    
    for (const auto &slot : _slots) {
        if (!slot.active || !slot.lastValueValid) continue;
        uint64_t currentValue = 0;
        if (readSlotValueLocked(slot, currentValue) &&
            currentValue != slot.lastValue) {
            return slot.index;
        }
    }
    
    uint32_t activeSlot = MAX_SLOTS;
    uint32_t activeCount = 0;
    for (const auto &slot : _slots) {
        if (!slot.active) continue;
        activeSlot = slot.index;
        activeCount++;
    }
    return activeCount == 1 ? activeSlot : MAX_SLOTS;
}

#pragma mark - Symbolication

StackFrame DebugCore::symbolicate(uint64_t pc) {
    StackFrame frame{};
    frame.pc = pc;
    
    Dl_info info;
    if (dladdr((void *)pc, &info)) {
        if (info.dli_fname) {
            // 提取文件名
            const char *name = strrchr(info.dli_fname, '/');
            frame.imageName = name ? (name + 1) : info.dli_fname;
        }
        frame.imageBase = (uint64_t)info.dli_fbase;
        frame.offset = pc - frame.imageBase;
    } else {
        frame.imageName = "???";
        frame.offset = pc;
    }
    
    return frame;
}

std::vector<StackFrame> DebugCore::captureStack(uint64_t pc, uint64_t lr, uint64_t fp) {
    std::vector<StackFrame> frames;
    
    // PC (当前指令)
    frames.push_back(symbolicate(pc));
    
    // LR (调用者)
    if (lr != 0) {
        frames.push_back(symbolicate(lr));
    }
    
    // 遍历栈帧 (FP chain) - 使用 readMem 安全读取
    uint64_t currentFP = fp;
    for (int depth = 0; depth < 16 && currentFP != 0; depth++) {
        uint64_t savedFP = 0;
        uint64_t savedLR = 0;
        
        // 读取 [FP] = saved FP, [FP+8] = saved LR
        if (currentFP % 8 != 0) break;
        
        // 安全读取: 通过 MemEngine::readMem 避免非法地址崩溃
        if (!MemEngine::inst().readMem(currentFP, &savedFP, sizeof(savedFP))) break;
        if (!MemEngine::inst().readMem(currentFP + 8, &savedLR, sizeof(savedLR))) break;
        
        if (savedLR == 0 || savedLR == lr) break;
        
        frames.push_back(symbolicate(savedLR));
        currentFP = savedFP;
    }
    
    return frames;
}

} // namespace vcore
