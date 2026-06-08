/**
 * VansonLoader L2.3 - Hardware Watchpoint Engine
 * ARM64 硬件断点监控 + 异常捕获 + 堆栈符号化
 * 当前进程 ARM64 硬件 watchpoint 能力探测
 */

#ifndef VLDebugCore_hpp
#define VLDebugCore_hpp

#include <cstdint>
#include <string>
#include <vector>
#include <mutex>
#include <functional>
#include <thread>
#include <mach/mach.h>

namespace vcore {

// 监控类型
enum class WatchType : uint8_t {
    Write = 0,
    Read = 1,
    ReadWrite = 2
};

// 监控大小
enum class WatchSize : uint8_t {
    Byte1 = 0,
    Byte2 = 1,
    Byte4 = 2,
    Byte8 = 3
};

// 堆栈帧
struct StackFrame {
    uint64_t pc;
    std::string imageName;
    uint64_t imageBase;
    uint64_t offset;       // pc - imageBase (静态偏移)
};

// 断点触发记录
struct WatchHit {
    uint32_t wpIndex;
    uint64_t pc;
    uint64_t lr;
    uint64_t address;      // 被监控的地址
    uint64_t newValue;     // 触发后的新值
    std::string imageName;
    uint64_t offset;       // 静态偏移 (制作补丁的关键)
    std::vector<StackFrame> stackTrace;
    double timestamp;
};

// 断点槽位
struct WatchSlot {
    uint32_t index;        // 0-3
    uint64_t address;
    uint64_t lastValue;
    WatchType type;
    WatchSize size;
    bool active;
    bool lastValueValid;
    std::vector<WatchHit> hits;
};

// 触发回调
using WatchHitCallback = std::function<void(const WatchHit &hit)>;

// 轻量级原始数据 (栈上分配，不涉及 malloc)
struct RawHitContext {
    uint64_t pc;
    uint64_t lr;
    uint64_t address;
    uint64_t exceptionCode;
    uint64_t exceptionSubcode;
    uint32_t wpIndex;
};

// 硬件断点引擎
class DebugCore {
public:
    static DebugCore &inst();
    
    static constexpr uint32_t MAX_SLOTS = 4;
    
    // 生命周期
    bool attach();                    // 附加到当前进程
    void detach();
    bool isAttached() const { return _attached; }
    bool probeAvailability();         // 当前进程运行时能力探测
    
    // 断点管理
    int addWatch(uint64_t address, WatchType type = WatchType::Write,
                 WatchSize size = WatchSize::Byte4);
    bool removeWatch(uint32_t index);
    void removeAll();
    
    // 状态查询
    const std::vector<WatchSlot> &getSlots() const { return _slots; }
    uint32_t activeCount() const;
    
    // 触发记录
    const std::vector<WatchHit> &getHits(uint32_t slotIndex) const;
    void clearHits(uint32_t slotIndex);
    void clearAllHits();
    
    // 回调
    void setHitCallback(WatchHitCallback cb);
    
    // 符号化
    static StackFrame symbolicate(uint64_t pc);
    static std::vector<StackFrame> captureStack(uint64_t pc, uint64_t lr, uint64_t fp);
    
private:
    DebugCore() = default;
    ~DebugCore();
    
    bool attachLocked();              // 内部版本，调用者已持有 _mutex
    bool setupExceptionPort();
    void listenerThread();
    void safeProcessHit(RawHitContext raw);  // 回复内核后异步处理
    
    bool applyToHardware(const WatchSlot &slot);
    bool clearHardware(uint32_t index);
    uint8_t basForSize(WatchSize size);
    size_t byteCountForSize(WatchSize size) const;
    bool slotContainsAddress(const WatchSlot &slot, uint64_t address) const;
    bool readSlotValueLocked(const WatchSlot &slot, uint64_t &value);
    bool slotAddressForIndex(uint32_t index, uint64_t &address);
    uint32_t resolveHitSlot(uint64_t exceptionCode, uint64_t exceptionSubcode);
    
    mach_port_t _task = MACH_PORT_NULL;
    mach_port_t _exceptionPort = MACH_PORT_NULL;
    bool _attached = false;
    bool _listening = false;
    
    std::vector<WatchSlot> _slots;
    std::mutex _mutex;
    std::mutex _hitMutex;          // 独立锁: 仅保护 hits 写入，避免与 _mutex 交叉死锁
    std::thread _listenerThread;
    WatchHitCallback _hitCallback;
    
    static const std::vector<WatchHit> _emptyHits;
};

} // namespace vcore

#endif /* VLDebugCore_hpp */
