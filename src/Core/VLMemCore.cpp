/**
 * VansonLoader L2.3 - Memory Core Implementation
 * 当前进程内存搜索引擎
 * 移植自 VansonMod 2.5，优化为当前进程直接访问
 */

#include "VLMemCore.hpp"
#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstring>
#include <dispatch/dispatch.h>
#include <mach/mach.h>
#include <mutex>
#include <set>
#include <sstream>
#include <unordered_map>
#include <unordered_set>


// mach_vm 声明
extern "C" {
kern_return_t mach_vm_read_overwrite(vm_map_t target_task,
                                     mach_vm_address_t address,
                                     mach_vm_size_t size,
                                     mach_vm_address_t data,
                                     mach_vm_size_t* out_size);
kern_return_t mach_vm_write(vm_map_t target_task, mach_vm_address_t address,
                            vm_offset_t data, mach_msg_type_number_t dataCnt);
kern_return_t mach_vm_region(vm_map_t target_task, mach_vm_address_t* address,
                             mach_vm_size_t* size, vm_region_flavor_t flavor,
                             vm_region_info_t info,
                             mach_msg_type_number_t* infoCnt,
                             mach_port_t* object_name);
kern_return_t mach_vm_protect(vm_map_t target_task, mach_vm_address_t address,
                              mach_vm_size_t size, boolean_t set_maximum,
                              vm_prot_t new_protection);
kern_return_t mach_vm_region_recurse(vm_map_t target_task,
                                     mach_vm_address_t* address,
                                     mach_vm_size_t* size,
                                     uint32_t* nesting_depth,
                                     vm_region_recurse_info_t info,
                                     mach_msg_type_number_t* infoCnt);
}

namespace vcore {

// 24-byte 磁盘存储结构
struct RawResult {
    uint64_t address;
    uint64_t value;
    uint8_t type;
    uint8_t padding[7];
};

static inline RawResult makeRawResult(uint64_t addr, uint64_t val, MemDataType type = MemDataType::Int32) {
    RawResult r;
    r.address = addr;
    r.value = val;
    r.type = (uint8_t)type;
    memset(r.padding, 0, sizeof(r.padding));
    return r;
}

static inline uint64_t regionEnd(uint64_t start, uint64_t size) {
    uint64_t end = start + size;
    return end < start ? UINT64_MAX : end;
}

// ============================================================================
// 构造/析构
// ============================================================================

MemCore::MemCore() 
    : _task(MACH_PORT_NULL)
    , _resultLimit(0)
    , _floatTolerance(0.001)
    , _groupSearchRange(200)
    , _groupAnchorMode(false)
    , _resultCount(0) {
}

MemCore::~MemCore() {
    clearFastFuzzySnapshot();
    // 当前进程模式不需要释放 task
}

void MemCore::init() {
    _task = mach_task_self();
}

// ============================================================================
// 内存读写 - 当前进程优化版本
// ============================================================================

bool MemCore::readMem(uint64_t address, void* buffer, size_t size) {
    if (_task == MACH_PORT_NULL || !buffer || size == 0) return false;
    
    // 当前进程优化：直接内存访问（带安全检查）
    // 对于当前进程，可以直接 memcpy，但为了安全性仍使用 mach_vm
    mach_vm_size_t readSize = 0;
    kern_return_t kr = mach_vm_read_overwrite(
        _task, address, size, (mach_vm_address_t)buffer, &readSize);
    return (kr == KERN_SUCCESS && readSize == size);
}

bool MemCore::writeMem(uint64_t address, const void* buffer, size_t size) {
    if (_task == MACH_PORT_NULL || !buffer || size == 0) return false;
    
    // 当前进程模式：先尝试直接写入
    kern_return_t kr = mach_vm_write(_task, address, (vm_offset_t)buffer,
                                     (mach_msg_type_number_t)size);
    if (kr == KERN_SUCCESS) return true;
    
    // 写入失败，尝试修改内存保护属性
    // 先获取当前保护属性
    mach_vm_address_t regionAddr = address;
    mach_vm_size_t regionSize = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t objectName = MACH_PORT_NULL;
    
    kr = mach_vm_region(_task, &regionAddr, &regionSize,
                        VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info,
                        &infoCount, &objectName);
    if (kr != KERN_SUCCESS) return false;
    
    vm_prot_t oldProt = info.protection;
    
    // 添加写权限
    kr = mach_vm_protect(_task, address, size, FALSE,
                        VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) return false;
    
    // 重试写入
    kr = mach_vm_write(_task, address, (vm_offset_t)buffer,
                      (mach_msg_type_number_t)size);
    
    // 恢复原保护属性
    mach_vm_protect(_task, address, size, FALSE, oldProt);
    
    return (kr == KERN_SUCCESS);
}

// ============================================================================
// 值解析
// ============================================================================

void MemCore::parseValue(const std::string& valStr, MemDataType type, void* outVal) {
    try {
        switch (type) {
            case MemDataType::Int8:
                *(int8_t*)outVal = (int8_t)std::stoi(valStr);
                break;
            case MemDataType::Int16:
                *(int16_t*)outVal = (int16_t)std::stoi(valStr);
                break;
            case MemDataType::Int32:
                *(int32_t*)outVal = std::stoi(valStr);
                break;
            case MemDataType::Int64:
                *(int64_t*)outVal = std::stoll(valStr);
                break;
            case MemDataType::UInt8:
                *(uint8_t*)outVal = (uint8_t)std::stoul(valStr);
                break;
            case MemDataType::UInt16:
                *(uint16_t*)outVal = (uint16_t)std::stoul(valStr);
                break;
            case MemDataType::UInt32:
                *(uint32_t*)outVal = (uint32_t)std::stoul(valStr);
                break;
            case MemDataType::UInt64:
                *(uint64_t*)outVal = std::stoull(valStr);
                break;
            case MemDataType::Float:
                *(float*)outVal = std::stof(valStr);
                break;
            case MemDataType::Double:
                *(double*)outVal = std::stod(valStr);
                break;
            default:
                break;
        }
    } catch (...) {
        memset(outVal, 0, 8);
    }
}

static MemDataType getTypeFromSuffix(std::string& valStr, MemDataType defaultType) {
    size_t spacePos = valStr.find_last_of(' ');
    if (spacePos != std::string::npos) {
        std::string suffix = valStr.substr(spacePos + 1);
        suffix.erase(0, suffix.find_first_not_of("\t\n\v\f\r "));
        std::transform(suffix.begin(), suffix.end(), suffix.begin(), ::tolower);
        
        MemDataType type = defaultType;
        bool found = true;
        
        if (suffix == "i8") type = MemDataType::Int8;
        else if (suffix == "i16") type = MemDataType::Int16;
        else if (suffix == "i32") type = MemDataType::Int32;
        else if (suffix == "i64") type = MemDataType::Int64;
        else if (suffix == "f32") type = MemDataType::Float;
        else if (suffix == "f64") type = MemDataType::Double;
        else if (suffix == "u8") type = MemDataType::UInt8;
        else if (suffix == "u16") type = MemDataType::UInt16;
        else if (suffix == "u32") type = MemDataType::UInt32;
        else if (suffix == "u64") type = MemDataType::UInt64;
        else found = false;
        
        if (found) {
            valStr = valStr.substr(0, spacePos);
            return type;
        }
    }
    return defaultType;
}

std::vector<GroupItem> MemCore::parseGroupString(const std::string& groupStr,
                                                  MemDataType defaultType,
                                                  uint64_t& outRange) {
    std::vector<GroupItem> items;
    std::string parseStr = groupStr;
    
    // 解析范围 ::
    size_t rangePos = groupStr.find("::");
    if (rangePos != std::string::npos) {
        std::string rangePart = groupStr.substr(rangePos + 2);
        try {
            if (rangePart.find("0x") == 0)
                outRange = std::stoull(rangePart, nullptr, 16);
            else
                outRange = std::stoull(rangePart);
        } catch (...) {}
        parseStr = groupStr.substr(0, rangePos);
    }
    
    // 解析值列表
    std::vector<std::string> rawItems;
    if (parseStr.find(';') != std::string::npos) {
        std::stringstream ss(parseStr);
        std::string s;
        while (std::getline(ss, s, ';'))
            rawItems.push_back(s);
    } else {
        std::string current;
        for (size_t i = 0; i < parseStr.size(); ++i) {
            char c = parseStr[i];
            if (c == ' ' || c == '\t') {
                if (!current.empty()) {
                    rawItems.push_back(current);
                    current.clear();
                }
            } else if (c == '-') {
                if (current.empty()) {
                    current += c;
                } else {
                    rawItems.push_back(current);
                    current = "-";
                }
            } else {
                current += c;
            }
        }
        if (!current.empty()) rawItems.push_back(current);
    }
    
    for (auto& raw : rawItems) {
        raw.erase(0, raw.find_first_not_of(" \t\n\r"));
        raw.erase(raw.find_last_not_of(" \t\n\r") + 1);
        if (raw.empty()) continue;
        
        MemDataType itemType = getTypeFromSuffix(raw, defaultType);
        GroupItem item;
        item.type = itemType;
        item.relative = false;
        memset(&item.value, 0, sizeof(item.value));
        parseValue(raw, itemType, &item.value);
        items.push_back(item);
    }
    return items;
}

void MemCore::parseRangeString(const std::string& rangeStr, MemDataType type,
                               void* minVal, void* maxVal) {
    std::string s = rangeStr;
    size_t comma = s.find(',');
    if (comma != std::string::npos) {
        std::string v1 = s.substr(0, comma);
        std::string v2 = s.substr(comma + 1);
        parseValue(v1, type, minVal);
        parseValue(v2, type, maxVal);
    } else {
        parseValue(s, type, minVal);
        parseValue(s, type, maxVal);
    }
}

void MemCore::setStoragePath(const std::string& path, const std::string& swapPath) {
    _storagePath = path;
    _swapPath = swapPath;
    _fastFuzzySnapshotPath = path + ".fuzzy";
}

bool MemCore::restoreResultsFromFile(const std::string& filePath, size_t resultCount) {
    if (_storagePath.empty()) return false;

    ::remove(_storagePath.c_str());
    if (filePath.empty() || resultCount == 0) {
        _resultCount = 0;
        return true;
    }

    if (::rename(filePath.c_str(), _storagePath.c_str()) != 0) return false;
    _resultCount = resultCount;
    return true;
}


// ============================================================================
// 首次搜索
// ============================================================================

std::vector<ScanResult> MemCore::scan(MemDataType type, const std::string& valueStr,
                                       int searchMode, uint64_t start, uint64_t end) {
    _resultCount = 0;
    std::vector<ScanResult> emptyRes;
    if (_task == MACH_PORT_NULL || _storagePath.empty()) return emptyRes;
    
    FILE* outFile = fopen(_storagePath.c_str(), "wb");
    if (!outFile) return emptyRes;
    
    uint64_t endAddress = end;
    if (endAddress == 0) {
        endAddress = 0x900000000ULL;
    }
    
    // 解析目标值
    union {
        int8_t i8; int16_t i16; int32_t i32; int64_t i64;
        uint8_t u8; uint16_t u16; uint32_t u32; uint64_t u64;
        float f; double d;
    } target, minVal, maxVal;
    memset(&target, 0, sizeof(target));
    memset(&minVal, 0, sizeof(minVal));
    memset(&maxVal, 0, sizeof(maxVal));
    
    MemDataType dType = type;
    size_t dSize = getSizeForType(type);
    
    bool isAutoTypeSearch = isAutoType(type);
    std::vector<MemDataType> autoSubTypes;
    if (isAutoTypeSearch) {
        autoSubTypes = getSubTypesForAuto(type);
        dSize = 1;
    }
    
    std::vector<GroupItem> gItems;
    uint64_t groupRange = _groupSearchRange;
    
    if (searchMode == 2) {  // Group
        gItems = parseGroupString(valueStr, type, groupRange);
        if (gItems.empty()) searchMode = 0;
    } else if (searchMode == 3) {  // Between
        parseRangeString(valueStr, type, &minVal, &maxVal);
    } else {
        if (isAutoTypeSearch) {
            if (type == MemDataType::FloatAuto)
                parseValue(valueStr, MemDataType::Double, &target);
            else
                parseValue(valueStr, MemDataType::Int64, &target);
        } else {
            parseValue(valueStr, type, &target);
        }
    }
    
    // 收集内存区域
    struct Region { uint64_t start; uint64_t size; };
    std::vector<Region> regions;
    
    mach_vm_address_t address = (start > 0) ? start : 0x100000000;
    mach_vm_size_t size = 0;
    uint32_t depth = 0;
    mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
    vm_region_submap_info_data_64_t info;
    
    while (true) {
        if (endAddress > 0 && address >= endAddress) break;
        count = VM_REGION_SUBMAP_INFO_COUNT_64;
        kern_return_t kr = mach_vm_region_recurse(
            _task, &address, &size, &depth,
            (vm_region_recurse_info_t)&info, &count);
        if (kr != KERN_SUCCESS) break;
        
        if ((info.protection & VM_PROT_READ) && (info.protection & VM_PROT_WRITE)) {
            if (size <= 1024 * 1024 * 1024) {
                regions.push_back({address, size});
            }
        }
        uint64_t nextAddress = regionEnd(address, size);
        if (nextAddress <= address) break;
        address = nextAddress;
    }
    
    std::sort(regions.begin(), regions.end(),
              [](const Region& a, const Region& b) { return a.start < b.start; });
    
    // 搜索参数捕获
    bool isFloatTypeLocal = vcore::isFloatType(type);
    bool isStringType = (dType == MemDataType::String);
    std::string targetString = valueStr;
    size_t targetStringLen = targetString.length();
    mach_port_t task = _task;
    double floatTolerance = _floatTolerance;
    
    float targetFloat = target.f;
    double targetDouble = target.d;
    int64_t targetInt64 = target.i64;
    
    uint64_t targetUInt64 = 0;
    switch (dType) {
        case MemDataType::Int8:   targetUInt64 = (uint64_t)(uint8_t)target.i8; break;
        case MemDataType::Int16:  targetUInt64 = (uint64_t)(uint16_t)target.i16; break;
        case MemDataType::Int32:  targetUInt64 = (uint64_t)(uint32_t)target.i32; break;
        case MemDataType::Int64:  targetUInt64 = (uint64_t)target.i64; break;
        case MemDataType::UInt8:  targetUInt64 = target.u8; break;
        case MemDataType::UInt16: targetUInt64 = target.u16; break;
        case MemDataType::UInt32: targetUInt64 = target.u32; break;
        case MemDataType::UInt64: targetUInt64 = target.u64; break;
        default: targetUInt64 = target.u64; break;
    }
    
    float minFloat = minVal.f, maxFloat = maxVal.f;
    double minDouble = minVal.d, maxDouble = maxVal.d;
    int64_t minInt64 = minVal.i64, maxInt64 = maxVal.i64;
    
    // 模糊搜索初始化
    if (searchMode == 1) {
        size_t chunkBufferSize = 1024 * 1024;
        uint8_t* memBuffer = (uint8_t*)malloc(chunkBufferSize);
        if (memBuffer) {
            for (const auto& r : regions) {
                uint64_t rEnd = std::min(regionEnd(r.start, r.size), endAddress);
                uint64_t curr = r.start;
                while (curr < rEnd) {
                    uint64_t chunkSize = std::min(chunkBufferSize, (size_t)(rEnd - curr));
                    mach_vm_size_t readSize = chunkSize;
                    if (mach_vm_read_overwrite(task, curr, chunkSize,
                                               (mach_vm_address_t)memBuffer,
                                               &readSize) == KERN_SUCCESS) {
                        size_t limit = readSize >= dSize ? readSize - dSize : 0;
                        std::vector<RawResult> chunkResults;
                        for (size_t k = 0; k <= limit; k += dSize) {
                            uint64_t val = 0;
                            memcpy(&val, memBuffer + k, std::min((size_t)8, dSize));
                            chunkResults.push_back(makeRawResult(curr + k, val, dType));
                        }
                        if (!chunkResults.empty()) {
                            fwrite(chunkResults.data(), sizeof(RawResult),
                                   chunkResults.size(), outFile);
                            _resultCount += chunkResults.size();
                        }
                    }
                    curr += chunkSize;
                }
            }
            free(memBuffer);
        }
    } else {
        // 并行搜索
        std::vector<std::vector<RawResult>> perRegionResults(regions.size());
        std::vector<RawResult>* perRegionResultsPtr = perRegionResults.data();
        
        int dataTypeInt = (int)dType;
        size_t dataSizeLocal = dSize;
        int searchModeLocal = searchMode;
        std::vector<GroupItem> gItemsCopy = gItems;
        uint64_t groupRangeLocal = groupRange;
        bool groupAnchorModeLocal = _groupAnchorMode;
        bool isAutoTypeLocal = isAutoTypeSearch;
        std::vector<MemDataType> autoSubTypesLocal = autoSubTypes;
        bool isStringTypeLocal = isStringType;
        std::string targetStringLocal = targetString;
        size_t targetStringLenLocal = targetStringLen;
        
        dispatch_apply(regions.size(),
                       dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
                       ^(size_t i) {
            Region r = regions[i];
            uint64_t rEnd = std::min(regionEnd(r.start, r.size), endAddress);
            size_t chunkBufferSize = 1024 * 1024;
            uint8_t* memBuffer = (uint8_t*)malloc(chunkBufferSize);
            if (!memBuffer) return;
            
            std::vector<RawResult>& localResults = perRegionResultsPtr[i];
            uint64_t curr = r.start;
            
            while (curr < rEnd) {
                uint64_t chunkSize = std::min(chunkBufferSize, (size_t)(rEnd - curr));
                mach_vm_size_t readSize = chunkSize;
                if (mach_vm_read_overwrite(task, curr, chunkSize,
                                           (mach_vm_address_t)memBuffer,
                                           &readSize) == KERN_SUCCESS) {
                    size_t limit;
                    if (isStringTypeLocal && targetStringLenLocal > 0) {
                        limit = readSize >= targetStringLenLocal ? readSize - targetStringLenLocal : 0;
                    } else {
                        limit = readSize >= dataSizeLocal ? readSize - dataSizeLocal : 0;
                    }
                    size_t step = dataSizeLocal;
                    
                    if (searchModeLocal == 2 && !gItemsCopy.empty()) {
                        step = getSizeForType(gItemsCopy[0].type);
                    } else if (isStringTypeLocal) {
                        step = 1;
                    } else if (isAutoTypeLocal) {
                        step = (dataTypeInt == (int)MemDataType::FloatAuto) ? 4 : 1;
                    }
                    
                    for (size_t k = 0; k <= limit; k += step) {
                        bool match = false;
                        uint64_t valBits = 0;
                        void* ptr = memBuffer + k;
                        
                        if (searchModeLocal == 2 && !gItemsCopy.empty()) {
                            // ========== 联合搜索实现 ==========
                            const auto& firstItem = gItemsCopy[0];
                            bool firstMatch = false;
                            bool firstIsFloat = vcore::isFloatType(firstItem.type);
                            
                            if (firstIsFloat) {
                                double v = (firstItem.type == MemDataType::Float)
                                    ? *(float*)ptr : *(double*)ptr;
                                double tgtVal = (firstItem.type == MemDataType::Float)
                                    ? (double)firstItem.value.f : firstItem.value.d;
                                if (std::abs(v - tgtVal) <= floatTolerance)
                                    firstMatch = true;
                            } else {
                                size_t sz = getSizeForType(firstItem.type);
                                int64_t v = 0, target = 0;
                                switch (firstItem.type) {
                                    case MemDataType::Int8:   v = *(int8_t*)ptr; target = firstItem.value.i8; break;
                                    case MemDataType::Int16:  v = *(int16_t*)ptr; target = firstItem.value.i16; break;
                                    case MemDataType::Int32:  v = *(int32_t*)ptr; target = firstItem.value.i32; break;
                                    case MemDataType::Int64:  v = *(int64_t*)ptr; target = firstItem.value.i64; break;
                                    default: {
                                        uint64_t uv = 0;
                                        memcpy(&uv, ptr, sz > 8 ? 8 : sz);
                                        v = (int64_t)uv;
                                        target = (int64_t)firstItem.value.u64;
                                        break;
                                    }
                                }
                                // Int64 高位剥离处理（用于指针搜索）
                                if (v == target || (firstItem.type == MemDataType::Int64 &&
                                    (v & 0xFFFFFFFFFFFF) == (target & 0xFFFFFFFFFFFF)))
                                    firstMatch = true;
                            }
                            
                            if (firstMatch) {
                                bool allMatched = true;
                                std::vector<uint64_t> matchedAddrs;
                                matchedAddrs.push_back(curr + k);
                                size_t anchorOffset = k;
                                size_t lastMatchOffset = k;
                                
                                for (size_t g = 1; g < gItemsCopy.size(); ++g) {
                                    const auto& nextItem = gItemsCopy[g];
                                    bool foundNext = false;
                                    size_t nextSz = getSizeForType(nextItem.type);
                                    bool nextIsFloat = vcore::isFloatType(nextItem.type);
                                    
                                    size_t minOff, maxOff;
                                    if (groupAnchorModeLocal) {
                                        minOff = (k > groupRangeLocal) ? k - groupRangeLocal : 0;
                                        maxOff = std::min((size_t)readSize, (size_t)(k + groupRangeLocal + 1));
                                    } else {
                                        minOff = lastMatchOffset + 1;
                                        maxOff = std::min((size_t)readSize, (size_t)(lastMatchOffset + groupRangeLocal + 1));
                                    }
                                    
                                    for (size_t off = minOff; off < maxOff; ++off) {
                                        if (groupAnchorModeLocal && off == anchorOffset) continue;
                                        if (off + nextSz > readSize) continue;
                                        void* nPtr = memBuffer + off;
                                        
                                        if (nextIsFloat) {
                                            double nv = (nextItem.type == MemDataType::Float)
                                                ? *(float*)nPtr : *(double*)nPtr;
                                            double nTargetVal = (nextItem.type == MemDataType::Float)
                                                ? (double)nextItem.value.f : nextItem.value.d;
                                            if (std::abs(nv - nTargetVal) <= floatTolerance) {
                                                foundNext = true;
                                                matchedAddrs.push_back(curr + off);
                                                lastMatchOffset = off;
                                                break;
                                            }
                                        } else {
                                            int64_t nv = 0, nTarget = 0;
                                            switch (nextItem.type) {
                                                case MemDataType::Int8:   nv = *(int8_t*)nPtr; nTarget = nextItem.value.i8; break;
                                                case MemDataType::Int16:  nv = *(int16_t*)nPtr; nTarget = nextItem.value.i16; break;
                                                case MemDataType::Int32:  nv = *(int32_t*)nPtr; nTarget = nextItem.value.i32; break;
                                                case MemDataType::Int64:  nv = *(int64_t*)nPtr; nTarget = nextItem.value.i64; break;
                                                default: {
                                                    uint64_t uv = 0;
                                                    memcpy(&uv, nPtr, nextSz > 8 ? 8 : nextSz);
                                                    nv = (int64_t)uv;
                                                    nTarget = (int64_t)nextItem.value.u64;
                                                    break;
                                                }
                                            }
                                            // Int64 高位剥离处理
                                            if (nv == nTarget || (nextItem.type == MemDataType::Int64 &&
                                                (nv & 0xFFFFFFFFFFFF) == (nTarget & 0xFFFFFFFFFFFF))) {
                                                foundNext = true;
                                                matchedAddrs.push_back(curr + off);
                                                lastMatchOffset = off;
                                                break;
                                            }
                                        }
                                    }
                                    if (!foundNext) {
                                        allMatched = false;
                                        break;
                                    }
                                }
                                
                                if (allMatched) {
                                    std::sort(matchedAddrs.begin(), matchedAddrs.end());
                                    size_t writeCount = std::min(matchedAddrs.size(), gItemsCopy.size());
                                    for (size_t wc = 0; wc < writeCount; ++wc) {
                                        uint64_t addr = matchedAddrs[wc];
                                        RawResult res;
                                        res.address = addr;
                                        res.type = (uint8_t)gItemsCopy[wc].type;
                                        res.value = 0;
                                        size_t valueSize = getSizeForType(gItemsCopy[wc].type);
                                        memcpy(&res.value, memBuffer + (addr - curr),
                                               std::min((size_t)8, valueSize));
                                        memset(res.padding, 0, sizeof(res.padding));
                                        localResults.push_back(res);
                                    }
                                }
                            }
                        } else if (searchModeLocal == 3) {  // Range
                            if (isFloatTypeLocal) {
                                double v = (dataTypeInt == (int)MemDataType::Float) 
                                    ? (double)(*(float*)ptr) : *(double*)ptr;
                                double minV = (dataTypeInt == (int)MemDataType::Float) 
                                    ? (double)minFloat : minDouble;
                                double maxV = (dataTypeInt == (int)MemDataType::Float) 
                                    ? (double)maxFloat : maxDouble;
                                match = (v >= minV && v <= maxV);
                                valBits = (dataTypeInt == (int)MemDataType::Float) 
                                    ? *(uint32_t*)ptr : *(uint64_t*)ptr;
                            } else {
                                uint64_t v = 0;
                                memcpy(&v, ptr, dataSizeLocal > 8 ? 8 : dataSizeLocal);
                                match = (v >= (uint64_t)minInt64 && v <= (uint64_t)maxInt64);
                                valBits = v;
                            }
                        } else if (isStringTypeLocal) {
                            // String search: memcmp
                            if (targetStringLenLocal > 0 && k + targetStringLenLocal <= readSize) {
                                if (memcmp(ptr, targetStringLocal.c_str(), targetStringLenLocal) == 0) {
                                    match = true;
                                    valBits = 0;
                                }
                            }
                        } else {  // Exact
                            if (isAutoTypeLocal) {
                                MemDataType matchedType = dType;
                                for (MemDataType subType : autoSubTypesLocal) {
                                    size_t subSize = getSizeForType(subType);
                                    if (k + subSize > readSize) continue;
                                    
                                    bool subMatch = false;
                                    uint64_t subValBits = 0;
                                    
                                    if (subType == MemDataType::Float) {
                                        float v = *(float*)ptr;
                                        subMatch = (std::abs((double)v - targetDouble) <= floatTolerance);
                                        memcpy(&subValBits, ptr, 4);
                                    } else if (subType == MemDataType::Double) {
                                        double v = *(double*)ptr;
                                        subMatch = (std::abs(v - targetDouble) <= floatTolerance);
                                        memcpy(&subValBits, ptr, 8);
                                    } else {
                                        int64_t v = 0;
                                        switch (subType) {
                                            case MemDataType::Int8:   v = *(int8_t*)ptr; subValBits = (uint64_t)(uint8_t)v; break;
                                            case MemDataType::Int16:  v = *(int16_t*)ptr; subValBits = (uint64_t)(uint16_t)v; break;
                                            case MemDataType::Int32:  v = *(int32_t*)ptr; subValBits = (uint64_t)(uint32_t)v; break;
                                            case MemDataType::Int64:  v = *(int64_t*)ptr; subValBits = (uint64_t)v; break;
                                            case MemDataType::UInt8:  v = *(uint8_t*)ptr; subValBits = (uint64_t)*(uint8_t*)ptr; break;
                                            case MemDataType::UInt16: v = *(uint16_t*)ptr; subValBits = (uint64_t)*(uint16_t*)ptr; break;
                                            case MemDataType::UInt32: v = *(uint32_t*)ptr; subValBits = (uint64_t)*(uint32_t*)ptr; break;
                                            case MemDataType::UInt64: v = (int64_t)*(uint64_t*)ptr; subValBits = *(uint64_t*)ptr; break;
                                            default: break;
                                        }
                                        subMatch = (v == targetInt64);
                                    }
                                    
                                    if (subMatch) {
                                        match = true;
                                        valBits = subValBits;
                                        matchedType = subType;
                                        break;
                                    }
                                }
                                if (match) {
                                    localResults.push_back(makeRawResult(curr + k, valBits, matchedType));
                                    continue;
                                }
                            } else if (isFloatTypeLocal) {
                                double v = (dataTypeInt == (int)MemDataType::Float) 
                                    ? (double)(*(float*)ptr) : *(double*)ptr;
                                double tgtVal = (dataTypeInt == (int)MemDataType::Float) 
                                    ? (double)targetFloat : targetDouble;
                                match = (std::abs(v - tgtVal) <= floatTolerance);
                                valBits = (dataTypeInt == (int)MemDataType::Float) 
                                    ? *(uint32_t*)ptr : *(uint64_t*)ptr;
                            } else {
                                uint64_t v = 0;
                                memcpy(&v, ptr, dataSizeLocal > 8 ? 8 : dataSizeLocal);
                                // Int64 高位剥离处理（用于指针搜索）
                                if (dataTypeInt == (int)MemDataType::Int64) {
                                    uint64_t stripped = v & 0xFFFFFFFFFFFF;
                                    match = (v == targetUInt64 || stripped == targetUInt64);
                                } else {
                                    match = (v == targetUInt64);
                                }
                                valBits = v;
                            }
                        }
                        
                        if (match) {
                            localResults.push_back(makeRawResult(curr + k, valBits, dType));
                        }
                    }
                }
                curr += chunkSize;
            }
            free(memBuffer);
        });
        
        // 联合搜索结果排序
        if (searchMode == 2 && !gItems.empty()) {
            std::vector<RawResult> allResults;
            for (size_t i = 0; i < perRegionResults.size(); ++i) {
                allResults.insert(allResults.end(),
                                 perRegionResults[i].begin(),
                                 perRegionResults[i].end());
            }
            
            size_t groupSize = gItems.size();
            if (groupSize > 0 && allResults.size() >= groupSize) {
                std::vector<std::vector<RawResult>> groups;
                for (size_t i = 0; i + groupSize <= allResults.size(); i += groupSize) {
                    std::vector<RawResult> group(allResults.begin() + i,
                                                 allResults.begin() + i + groupSize);
                    groups.push_back(group);
                }
                
                std::sort(groups.begin(), groups.end(),
                          [](const std::vector<RawResult>& a, const std::vector<RawResult>& b) {
                              return a[0].address < b[0].address;
                          });
                
                allResults.clear();
                for (const auto& group : groups) {
                    allResults.insert(allResults.end(), group.begin(), group.end());
                }
            }
            
            if (!allResults.empty()) {
                fwrite(allResults.data(), sizeof(RawResult), allResults.size(), outFile);
                _resultCount = allResults.size();
            }
        } else {
            // 写入结果
            for (size_t i = 0; i < perRegionResults.size(); ++i) {
                if (!perRegionResults[i].empty()) {
                    fwrite(perRegionResults[i].data(), sizeof(RawResult),
                           perRegionResults[i].size(), outFile);
                    _resultCount += perRegionResults[i].size();
                }
            }
        }
    }
    fclose(outFile);
    return getResults(0, 100);
}


// ============================================================================
// 二次搜索
// ============================================================================

std::vector<ScanResult> MemCore::nextScan(MemDataType type, const std::string& valueStr, int searchMode) {
    std::vector<ScanResult> emptyRes;
    if (_task == MACH_PORT_NULL || _resultCount == 0 || _storagePath.empty()) return emptyRes;
    
    FILE* inFile = fopen(_storagePath.c_str(), "rb");
    if (!inFile) return emptyRes;
    
    FILE* outFile = fopen(_swapPath.c_str(), "wb");
    if (!outFile) { fclose(inFile); return emptyRes; }
    
    union { int8_t i8; int16_t i16; int32_t i32; int64_t i64; float f; double d; } target;
    memset(&target, 0, sizeof(target));
    
    bool isAutoTypeNextScan = isAutoType(type);
    if (isAutoTypeNextScan) {
        if (type == MemDataType::FloatAuto)
            parseValue(valueStr, MemDataType::Double, &target);
        else
            parseValue(valueStr, MemDataType::Int64, &target);
    } else {
        parseValue(valueStr, type, &target);
    }
    
    std::string targetString = valueStr;
    size_t targetStringLen = targetString.length();
    
    mach_port_t task = _task;
    double floatTolerance = _floatTolerance;
    float targetFloat = target.f;
    double targetDouble = target.d;
    int8_t targetI8 = isAutoTypeNextScan ? (int8_t)target.i64 : target.i8;
    int16_t targetI16 = isAutoTypeNextScan ? (int16_t)target.i64 : target.i16;
    int32_t targetI32 = isAutoTypeNextScan ? (int32_t)target.i64 : target.i32;
    int64_t targetI64 = target.i64;
    
    std::atomic<size_t> newCount(0);
    const size_t batchSize = 100000;
    std::vector<RawResult> batch(batchSize);
    
    while (true) {
        size_t readCount = fread(batch.data(), sizeof(RawResult), batchSize, inFile);
        if (readCount == 0) break;
        
        std::vector<RawResult> outputBatch;
        outputBatch.reserve(readCount);
        
        for (size_t i = 0; i < readCount; i++) {
            const RawResult& raw = batch[i];
            MemDataType storedType = (MemDataType)raw.type;
            size_t actualSize = getSizeForType(storedType);
            
            uint8_t buf[8] = {0};
            mach_vm_size_t rSz = actualSize;
            if (mach_vm_read_overwrite(task, raw.address, actualSize,
                                       (mach_vm_address_t)buf, &rSz) != KERN_SUCCESS) continue;
            
            bool match = false;
            if (storedType == MemDataType::String) {
                // String: re-read and compare
                if (targetStringLen > 0) {
                    std::vector<uint8_t> strBuf(targetStringLen);
                    mach_vm_size_t strSz = targetStringLen;
                    if (mach_vm_read_overwrite(task, raw.address, targetStringLen,
                                               (mach_vm_address_t)strBuf.data(), &strSz) == KERN_SUCCESS
                        && strSz == targetStringLen) {
                        match = (memcmp(strBuf.data(), targetString.c_str(), targetStringLen) == 0);
                    }
                }
            } else if (storedType == MemDataType::Float) {
                float oldVal = 0, newVal = 0;
                memcpy(&oldVal, &raw.value, 4);
                memcpy(&newVal, buf, 4);
                if (searchMode == 0) match = (newVal < oldVal - (float)floatTolerance);
                else if (searchMode == 1) match = (newVal > oldVal + (float)floatTolerance);
                else if (searchMode == 5) match = (fabs(newVal - oldVal) >= (float)floatTolerance);
                else if (searchMode == 6) match = (fabs(newVal - oldVal) < (float)floatTolerance);
                else match = (fabs(newVal - targetFloat) < (float)floatTolerance);
            } else if (storedType == MemDataType::Double) {
                double oldVal = 0, newVal = 0;
                memcpy(&oldVal, &raw.value, 8);
                memcpy(&newVal, buf, 8);
                if (searchMode == 0) match = (newVal < oldVal - floatTolerance);
                else if (searchMode == 1) match = (newVal > oldVal + floatTolerance);
                else if (searchMode == 5) match = (fabs(newVal - oldVal) >= floatTolerance);
                else if (searchMode == 6) match = (fabs(newVal - oldVal) < floatTolerance);
                else match = (fabs(newVal - targetDouble) < floatTolerance);
            } else {
                int64_t oldV = 0, newV = 0, targetV = 0;
                switch (actualSize) {
                    case 1: oldV = (int8_t)raw.value; newV = *(int8_t*)buf; targetV = targetI8; break;
                    case 2: oldV = (int16_t)raw.value; newV = *(int16_t*)buf; targetV = targetI16; break;
                    case 8: oldV = (int64_t)raw.value; newV = *(int64_t*)buf; targetV = targetI64; break;
                    default: oldV = (int32_t)raw.value; newV = *(int32_t*)buf; targetV = targetI32; break;
                }
                if (searchMode == 0) match = (newV < oldV);
                else if (searchMode == 1) match = (newV > oldV);
                else if (searchMode == 3) match = (newV == oldV + targetV);
                else if (searchMode == 4) match = (newV == oldV - targetV);
                else if (searchMode == 5) match = (newV != oldV);
                else if (searchMode == 6) match = (newV == oldV);
                else {
                    match = (newV == targetV);
                    // Int64 高位剥离处理（用于指针搜索）
                    if (!match && storedType == MemDataType::Int64) {
                        match = ((newV & 0xFFFFFFFFFFFF) == (targetV & 0xFFFFFFFFFFFF));
                    }
                }
            }
            
            if (match) {
                RawResult res;
                res.address = raw.address;
                memcpy(&res.value, buf, 8);
                res.type = raw.type;
                memset(res.padding, 0, sizeof(res.padding));
                outputBatch.push_back(res);
            }
        }
        
        if (!outputBatch.empty()) {
            fwrite(outputBatch.data(), sizeof(RawResult), outputBatch.size(), outFile);
            newCount += outputBatch.size();
        }
    }
    
    fclose(inFile);
    fclose(outFile);
    
    if (newCount == 0) {
        _resultCount = 0;
        remove(_swapPath.c_str());
        return emptyRes;
    }
    
    _resultCount = (size_t)newCount;
    remove(_storagePath.c_str());
    rename(_swapPath.c_str(), _storagePath.c_str());
    return getResults(0, 100);
}


// ============================================================================
// 结果管理
// ============================================================================

std::vector<ScanResult> MemCore::getResults(size_t start, size_t count) {
    std::vector<ScanResult> results;
    if (_storagePath.empty()) return results;
    
    FILE* f = fopen(_storagePath.c_str(), "rb");
    if (!f) return results;
    
    if (fseek(f, start * sizeof(RawResult), SEEK_SET) == 0) {
        RawResult raw;
        size_t read = 0;
        while (read < count && fread(&raw, sizeof(RawResult), 1, f) == 1) {
            ScanResult res;
            res.address = raw.address;
            res.value.u64 = raw.value;
            res.type = (MemDataType)raw.type;
            results.push_back(res);
            read++;
        }
    }
    fclose(f);
    return results;
}

std::vector<ScanResult> MemCore::scanNearby(MemDataType type, const std::string& valueStr, uint64_t range) {
    std::vector<ScanResult> results;
    if (_task == MACH_PORT_NULL || _resultCount == 0) return results;
    
    bool isStringType = (type == MemDataType::String);
    std::string targetString = valueStr;
    size_t targetStringLen = targetString.length();
    size_t dataSize = isStringType ? targetStringLen : getSizeForType(type);
    union { int8_t i8; int16_t i16; int32_t i32; int64_t i64; float f; double d; } target;
    memset(&target, 0, sizeof(target));
    if (!isStringType) parseValue(valueStr, type, &target);
    
    if (isStringType && targetStringLen == 0) return results;
    
    std::unordered_set<uint64_t> seenAddresses;
    
    auto scanRange = [&](uint64_t start, uint64_t len) {
        if (len > 65536) len = 65536;
        if (len < dataSize) return true;
        std::vector<uint8_t> buf(len);
        if (readMem(start, buf.data(), len)) {
            size_t maxOffset = len - dataSize;
            for (size_t i = 0; i <= maxOffset; i++) {
                bool match = false;
                void* ptr = buf.data() + i;
                if (isStringType) {
                    match = (memcmp(ptr, targetString.c_str(), targetStringLen) == 0);
                } else if (type == MemDataType::Float) {
                    match = (fabs(*(float*)ptr - target.f) <= (float)_floatTolerance);
                } else if (type == MemDataType::Double) {
                    match = (fabs(*(double*)ptr - target.d) <= _floatTolerance);
                } else {
                    if (dataSize == 4) match = (*(int32_t*)ptr == target.i32);
                    else if (dataSize == 8) match = (*(int64_t*)ptr == target.i64);
                    else if (dataSize == 2) match = (*(int16_t*)ptr == target.i16);
                    else if (dataSize == 1) match = (*(int8_t*)ptr == target.i8);
                }
                if (match) {
                    uint64_t addr = start + i;
                    if (seenAddresses.find(addr) != seenAddresses.end()) continue;
                    seenAddresses.insert(addr);
                    ScanResult res;
                    res.address = addr;
                    res.type = type;
                    res.value.u64 = 0;
                    memcpy(&res.value.u64, ptr, std::min((size_t)8, dataSize));
                    results.push_back(res);
                    if (_resultLimit > 0 && results.size() >= _resultLimit) return false;
                }
            }
        }
        return true;
    };
    
    if (!_storagePath.empty() && _resultCount > 0) {
        FILE* f = fopen(_storagePath.c_str(), "rb");
        if (f) {
            RawResult raw;
            while (fread(&raw, sizeof(RawResult), 1, f) == 1) {
                uint64_t start = (raw.address > range) ? (raw.address - range) : 0;
                if (!scanRange(start, range * 2)) break;
            }
            fclose(f);
        }
    }
    
    std::sort(results.begin(), results.end(),
              [](const ScanResult& a, const ScanResult& b) { return a.address < b.address; });

    if (!_storagePath.empty() && !_swapPath.empty()) {
        if (results.empty()) {
            ::remove(_storagePath.c_str());
            _resultCount = 0;
        } else {
            FILE* fOut = fopen(_swapPath.c_str(), "wb");
            if (fOut) {
                for (const auto& res : results) {
                    RawResult raw = makeRawResult(res.address, res.value.u64, res.type);
                    fwrite(&raw, sizeof(RawResult), 1, fOut);
                }
                fclose(fOut);
                ::remove(_storagePath.c_str());
                ::rename(_swapPath.c_str(), _storagePath.c_str());
                _resultCount = results.size();
            }
        }
    } else {
        _resultCount = results.size();
    }

    return results;
}

size_t MemCore::filterResults(FilterMode mode, MemDataType type,
                              const std::string& v1, const std::string& v2) {
    if (_storagePath.empty() || _swapPath.empty() || _resultCount == 0) return 0;
    
    FILE* fSrc = fopen(_storagePath.c_str(), "rb");
    FILE* fDst = fopen(_swapPath.c_str(), "wb");
    if (!fSrc || !fDst) {
        if (fSrc) fclose(fSrc);
        if (fDst) fclose(fDst);
        return 0;
    }
    
    double t1 = 0, t2 = 0;
    try { t1 = std::stod(v1); t2 = std::stod(v2); } catch (...) {}
    
    RawResult item;
    size_t newCount = 0;
    size_t dataSize = getSizeForType(type);
    
    while (fread(&item, sizeof(RawResult), 1, fSrc) == 1) {
        uint8_t buf[8] = {0};
        mach_vm_size_t rSz = dataSize;
        if (mach_vm_read_overwrite(_task, item.address, dataSize,
                                   (mach_vm_address_t)buf, &rSz) != KERN_SUCCESS) continue;
        
        double currentVal = 0;
        if (type == MemDataType::Float) currentVal = *(float*)buf;
        else if (type == MemDataType::Double) currentVal = *(double*)buf;
        else if (dataSize == 1) currentVal = *(int8_t*)buf;
        else if (dataSize == 2) currentVal = *(int16_t*)buf;
        else if (dataSize == 8) currentVal = *(int64_t*)buf;
        else currentVal = *(int32_t*)buf;
        
        bool keep = false;
        if (mode == FilterMode::Less) keep = (currentVal < t1);
        else if (mode == FilterMode::Greater) keep = (currentVal > t1);
        else if (mode == FilterMode::Between) keep = (currentVal >= t1 && currentVal <= t2);
        
        if (keep) {
            fwrite(&item, sizeof(RawResult), 1, fDst);
            newCount++;
        }
    }
    
    fclose(fSrc);
    fclose(fDst);
    remove(_storagePath.c_str());
    rename(_swapPath.c_str(), _storagePath.c_str());
    _resultCount = newCount;
    return newCount;
}

bool MemCore::removeResult(size_t index) {
    if (index >= _resultCount || _storagePath.empty()) return false;
    
    FILE* f = fopen(_storagePath.c_str(), "rb");
    if (!f) return false;
    
    fseek(f, 0, SEEK_END);
    size_t totalItems = ftell(f) / sizeof(RawResult);
    if (index >= totalItems) { fclose(f); return false; }
    
    std::string tempPath = _storagePath + ".tmp";
    FILE* fTmp = fopen(tempPath.c_str(), "wb");
    if (!fTmp) { fclose(f); return false; }
    
    fseek(f, 0, SEEK_SET);
    RawResult item;
    for (size_t i = 0; i < totalItems; i++) {
        if (fread(&item, sizeof(RawResult), 1, f) == 1 && i != index) {
            fwrite(&item, sizeof(RawResult), 1, fTmp);
        }
    }
    
    fclose(f);
    fclose(fTmp);
    remove(_storagePath.c_str());
    rename(tempPath.c_str(), _storagePath.c_str());
    _resultCount--;
    return true;
}

void MemCore::batchModify(const std::string& input, int limit, MemDataType type, int mode) {
    if (_storagePath.empty() || _resultCount == 0) return;
    
    FILE* f = fopen(_storagePath.c_str(), "rb");
    if (!f) return;
    
    double inputD = std::stod(input);
    long long inputI = std::stoll(input);
    RawResult raw;
    int processed = 0;
    int maxProcess = (limit > 0) ? limit : 2147483647;
    
    while (processed < maxProcess && fread(&raw, sizeof(RawResult), 1, f) == 1) {
        double finalD = inputD;
        long long finalI = inputI;
        if (mode == 1) { finalD += processed; finalI += processed; }
        
        size_t sz = getSizeForType(type);
        uint8_t buf[8];
        if (type == MemDataType::Float) { float v = (float)finalD; memcpy(buf, &v, 4); }
        else if (type == MemDataType::Double) memcpy(buf, &finalD, 8);
        else if (sz == 1) { int8_t v = (int8_t)finalI; memcpy(buf, &v, 1); }
        else if (sz == 2) { int16_t v = (int16_t)finalI; memcpy(buf, &v, 2); }
        else if (sz == 8) memcpy(buf, &finalI, 8);
        else { int32_t v = (int32_t)finalI; memcpy(buf, &v, 4); }
        
        writeMem(raw.address, buf, sz);
        processed++;
    }
    fclose(f);
}


// ============================================================================
// 快照系统
// ============================================================================

void MemCore::takeSnapshot(uint64_t maxTotalSize) {
    takeSnapshot(maxTotalSize, 0, 0);
}

void MemCore::takeSnapshot(uint64_t maxTotalSize, uint64_t priorityStart, uint64_t priorityEnd) {
    clearSnapshot();
    if (_task == MACH_PORT_NULL) return;
    
    uint64_t totalCaptured = 0;
    
    // 优先捕获指定范围
    if (priorityStart > 0 && priorityEnd > priorityStart) {
        mach_vm_address_t address = priorityStart;
        while (address < priorityEnd) {
            mach_vm_size_t size;
            vm_region_basic_info_data_64_t info;
            mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
            mach_port_t object_name;
            kern_return_t kr = mach_vm_region(_task, &address, &size, VM_REGION_BASIC_INFO_64,
                                              (vm_region_info_t)&info, &count, &object_name);
            if (kr != KERN_SUCCESS) break;
            
            if ((info.protection & VM_PROT_READ) && size <= 512 * 1024 * 1024) {
                SnapshotRegion region;
                region.start = address;
                region.data.resize(size);
                mach_vm_size_t readSize = size;
                if (mach_vm_read_overwrite(_task, address, size,
                                           (mach_vm_address_t)region.data.data(),
                                           &readSize) == KERN_SUCCESS) {
                    region.size = (uint32_t)readSize;
                    if (readSize != size) region.data.resize(readSize);
                    _snapshot.push_back(std::move(region));
                    totalCaptured += readSize;
                }
            }
            address += size;
        }
    }
    
    // 捕获标准堆范围
    mach_vm_address_t address = 0x100000000;
    mach_vm_address_t endLimit = 0x400000000;  // 当前进程使用较小范围
    
    while (address < endLimit && totalCaptured < maxTotalSize) {
        mach_vm_size_t size;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t object_name;
        kern_return_t kr = mach_vm_region(_task, &address, &size, VM_REGION_BASIC_INFO_64,
                                          (vm_region_info_t)&info, &count, &object_name);
        if (kr != KERN_SUCCESS) break;
        
        bool alreadyCaptured = false;
        for (const auto& sr : _snapshot) {
            if (address >= sr.start && address < (sr.start + sr.size)) {
                alreadyCaptured = true;
                break;
            }
        }
        
        if (!alreadyCaptured && (info.protection & VM_PROT_READ) && size <= 200 * 1024 * 1024) {
            SnapshotRegion region;
            region.start = address;
            region.data.resize(size);
            mach_vm_size_t readSize = size;
            if (mach_vm_read_overwrite(_task, address, size,
                                       (mach_vm_address_t)region.data.data(),
                                       &readSize) == KERN_SUCCESS) {
                region.size = (uint32_t)readSize;
                if (readSize != size) region.data.resize(readSize);
                _snapshot.push_back(std::move(region));
                totalCaptured += readSize;
            }
        }
        address += size;
    }
}

void MemCore::clearSnapshot() {
    _snapshot.clear();
    _snapshot.shrink_to_fit();
}

void MemCore::saveBaselineSnapshot() {
    if (_snapshot.empty()) takeSnapshot(1024 * 1024 * 1024);
    _baselineSnapshot = _snapshot;
}

void MemCore::clearBaselineSnapshot() {
    _baselineSnapshot.clear();
    _baselineSnapshot.shrink_to_fit();
}

std::vector<DiffRegion> MemCore::compareWithBaseline(uint64_t minChangeSize) {
    std::vector<DiffRegion> diffs;
    if (_baselineSnapshot.empty()) return diffs;
    if (_snapshot.empty()) takeSnapshot(1024 * 1024 * 1024);
    
    std::unordered_map<uint64_t, size_t> baselineIndex;
    for (size_t i = 0; i < _baselineSnapshot.size(); i++) {
        baselineIndex[_baselineSnapshot[i].start] = i;
    }
    
    for (const auto& currentRegion : _snapshot) {
        auto it = baselineIndex.find(currentRegion.start);
        if (it == baselineIndex.end()) {
            if (currentRegion.size >= minChangeSize) {
                diffs.push_back({currentRegion.start, currentRegion.size});
            }
            continue;
        }
        
        const auto& baselineRegion = _baselineSnapshot[it->second];
        size_t compareSize = std::min({(size_t)currentRegion.size, (size_t)baselineRegion.size,
                                       currentRegion.data.size(), baselineRegion.data.size()});
        
        size_t diffStart = 0;
        bool inDiff = false;
        
        for (size_t i = 0; i < compareSize; i++) {
            bool isDifferent = (currentRegion.data[i] != baselineRegion.data[i]);
            if (isDifferent && !inDiff) { diffStart = i; inDiff = true; }
            else if (!isDifferent && inDiff) {
                size_t diffSize = i - diffStart;
                if (diffSize >= minChangeSize) {
                    diffs.push_back({currentRegion.start + diffStart, (uint32_t)diffSize});
                }
                inDiff = false;
            }
        }
        if (inDiff) {
            size_t diffSize = compareSize - diffStart;
            if (diffSize >= minChangeSize) {
                diffs.push_back({currentRegion.start + diffStart, (uint32_t)diffSize});
            }
        }
    }
    return diffs;
}


// ============================================================================
// 特征码搜索
// ============================================================================

SignatureData MemCore::parseSignature(const std::string& sig) {
    SignatureData data;
    data.length = 0;
    data.firstValidIndex = -1;
    data.firstValidByte = 0;
    
    std::string clean = "";
    for (char c : sig) if (c != ' ') clean += toupper(c);
    if (clean.empty() || clean.length() % 2 != 0) return data;
    
    size_t len = clean.length() / 2;
    data.bytes.resize(len);
    data.mask.resize(len);
    data.length = len;
    
    for (size_t i = 0; i < len; i++) {
        std::string byteStr = clean.substr(i * 2, 2);
        if (byteStr == "??" || byteStr == "**" || byteStr == "--") {
            data.mask[i] = false;
            data.bytes[i] = 0;
        } else {
            data.mask[i] = true;
            data.bytes[i] = (uint8_t)strtoull(byteStr.c_str(), NULL, 16);
            if (data.firstValidIndex == -1) {
                data.firstValidIndex = (int)i;
                data.firstValidByte = data.bytes[i];
            }
        }
    }
    return data;
}

std::vector<ScanResult> MemCore::scanSignature(const std::string& sig, uint64_t start, uint64_t end) {
    std::vector<ScanResult> results;
    if (_task == MACH_PORT_NULL) return results;
    
    SignatureData sData = parseSignature(sig);
    if (sData.length == 0) return results;
    
    mach_vm_address_t address = (start > 0) ? start : 0x100000000;
    mach_vm_address_t endLimit = (end > 0) ? end : 0x200000000;
    
    struct MemRegion { uint64_t start; uint64_t size; };
    std::vector<MemRegion> regions;
    
    mach_vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object_name;
    
    while (address < endLimit) {
        kern_return_t kr = mach_vm_region(_task, &address, &size, VM_REGION_BASIC_INFO_64,
                                          (vm_region_info_t)&info, &infoCount, &object_name);
        if (kr != KERN_SUCCESS) break;
        if ((info.protection & VM_PROT_READ) && size > 0 && size <= 128 * 1024 * 1024) {
            regions.push_back({address, size});
        }
        address += size;
    }
    
    if (regions.empty()) return results;
    
    std::vector<uint8_t> fastMask(sData.length);
    for (size_t i = 0; i < sData.length; i++) fastMask[i] = sData.mask[i] ? 1 : 0;
    
    int anchorIndex = sData.firstValidIndex;
    uint8_t anchorByte = sData.firstValidByte;
    bool useFastPath = (anchorIndex != -1);
    
    const uint8_t* sigBytes = sData.bytes.data();
    const uint8_t* maskPtr = fastMask.data();
    size_t sigLen = sData.length;
    mach_port_t task = _task;
    
    std::vector<std::vector<ScanResult>> perRegionResults(regions.size());
    std::atomic<size_t> globalCount{0};
    const size_t kMaxResults = 200;
    
    std::vector<std::vector<ScanResult>>* resultsPtr = &perRegionResults;
    std::atomic<size_t>* countPtr = &globalCount;
    const std::vector<MemRegion>* regionsPtr = &regions;
    
    dispatch_apply(regions.size(),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
                   ^(size_t idx) {
        if (countPtr->load(std::memory_order_relaxed) >= kMaxResults) return;
        
        const MemRegion& reg = (*regionsPtr)[idx];
        if (reg.size < sigLen) return;
        
        uint8_t* buffer = (uint8_t*)malloc(reg.size);
        if (!buffer) return;
        
        mach_vm_size_t readSz = reg.size;
        if (mach_vm_read_overwrite(task, reg.start, reg.size,
                                   (mach_vm_address_t)buffer, &readSz) != KERN_SUCCESS) {
            free(buffer);
            return;
        }
        
        if (readSz < sigLen) { free(buffer); return; }
        
        std::vector<ScanResult> localResults;
        localResults.reserve(64);
        size_t scanLimit = readSz - sigLen + 1;
        size_t i = 0;
        
        while (i < scanLimit) {
            if (localResults.size() >= 50) break;
            
            if (useFastPath) {
                void* found = memchr(buffer + i + anchorIndex, anchorByte, readSz - (i + anchorIndex));
                if (!found) break;
                
                size_t foundPos = (uint8_t*)found - buffer;
                if (foundPos < (size_t)anchorIndex) { i++; continue; }
                
                size_t potentialStart = foundPos - anchorIndex;
                if (potentialStart < i) { i = foundPos + 1; continue; }
                if (potentialStart >= scanLimit) break;
                
                bool match = true;
                for (size_t k = 0; k < sigLen; k++) {
                    if (maskPtr[k] && buffer[potentialStart + k] != sigBytes[k]) {
                        match = false;
                        break;
                    }
                }
                
                if (match) {
                    ScanResult res;
                    res.address = reg.start + potentialStart;
                    res.type = MemDataType::Int8;
                    localResults.push_back(res);
                }
                i = potentialStart + 1;
            } else {
                ScanResult res;
                res.address = reg.start + i;
                res.type = MemDataType::Int8;
                localResults.push_back(res);
                i++;
            }
        }
        
        free(buffer);
        
        if (!localResults.empty()) {
            (*resultsPtr)[idx] = std::move(localResults);
            countPtr->fetch_add(localResults.size(), std::memory_order_relaxed);
        }
    });
    
    for (auto& localRes : perRegionResults) {
        for (auto& res : localRes) {
            if (results.size() >= kMaxResults) break;
            results.push_back(res);
        }
        if (results.size() >= kMaxResults) break;
    }
    
    std::sort(results.begin(), results.end(),
              [](const ScanResult& a, const ScanResult& b) { return a.address < b.address; });
    return results;
}


// ============================================================================
// 快速模糊搜索
// ============================================================================

void MemCore::fastFuzzyInit() {
    clearFastFuzzySnapshot();
    if (_task == MACH_PORT_NULL) return;

    if (_fastFuzzySnapshotPath.empty()) {
        _fastFuzzySnapshotPath = _storagePath + ".fuzzy";
    }
    if (_fastFuzzySnapshotPath.empty()) return;

    FILE* snapshotFile = fopen(_fastFuzzySnapshotPath.c_str(), "wb");
    if (!snapshotFile) return;

    _fastFuzzyAddressCount = 0;
    const uint64_t endAddress = 0x800000000;
    mach_vm_address_t address = 0x100000000;
    uint64_t totalCaptured = 0;
    const uint64_t maxTotalSize = 8ULL * 1024 * 1024 * 1024;
    const size_t chunkBufferSize = 32ULL * 1024 * 1024;

    while (address < endAddress && totalCaptured < maxTotalSize) {
        mach_vm_size_t size = 0;
        uint32_t depth = 0;
        mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
        vm_region_submap_info_data_64_t info;
        
        kern_return_t kr = mach_vm_region_recurse(_task, &address, &size, &depth,
                                                  (vm_region_recurse_info_t)&info, &count);
        if (kr != KERN_SUCCESS) break;
        
        if ((info.protection & VM_PROT_READ) && (info.protection & VM_PROT_WRITE)) {
            uint64_t regionStart = address;
            uint64_t regionEnd = std::min<uint64_t>(address + size, endAddress);
            for (uint64_t cursor = regionStart;
                 cursor < regionEnd && totalCaptured < maxTotalSize;) {
                uint64_t remainingRegion = regionEnd - cursor;
                uint64_t remainingBudget = maxTotalSize - totalCaptured;
                size_t chunkSize = (size_t)std::min<uint64_t>(
                    std::min<uint64_t>(remainingRegion, remainingBudget),
                    chunkBufferSize);
                if (chunkSize == 0) break;

                std::vector<uint8_t> buffer(chunkSize);
                mach_vm_size_t readSize = chunkSize;
                if (mach_vm_read_overwrite(_task, cursor, chunkSize,
                                           (mach_vm_address_t)buffer.data(),
                                           &readSize) == KERN_SUCCESS && readSize > 0) {
                    uint64_t fileOffset = (uint64_t)ftello(snapshotFile);
                    size_t written = fwrite(buffer.data(), 1, (size_t)readSize, snapshotFile);
                    if (written == (size_t)readSize) {
                        FastFuzzySnapshotRegion region;
                        region.start = cursor;
                        region.size = (uint64_t)readSize;
                        region.fileOffset = fileOffset;
                        _fastFuzzySnapshot.push_back(region);
                        if (readSize >= 4) {
                            _fastFuzzyAddressCount += (size_t)readSize - 3;
                        }
                        totalCaptured += readSize;
                    }
                }
                cursor += chunkSize;
            }
        }
        address += size;
    }

    fclose(snapshotFile);

    if (_fastFuzzySnapshot.empty()) {
        remove(_fastFuzzySnapshotPath.c_str());
    }
}

void MemCore::clearFastFuzzySnapshot() {
    _fastFuzzySnapshot.clear();
    _fastFuzzySnapshot.shrink_to_fit();
    _fastFuzzyAddressCount = 0;
    if (!_fastFuzzySnapshotPath.empty()) {
        remove(_fastFuzzySnapshotPath.c_str());
    }
}

size_t MemCore::getFastFuzzyAddressCount() const {
    return _fastFuzzyAddressCount;
}

void MemCore::updateFastFuzzySnapshotFromResults(MemDataType type) {
    (void)type;
    clearFastFuzzySnapshot();
}

std::vector<ScanResult> MemCore::fastFuzzyFilter(MemDataType type, int filterMode,
                                                  uint64_t start, uint64_t end) {
    std::vector<ScanResult> emptyRes;
    
    // [修复] 修改检查逻辑：有快照或有存储结果时都可以继续
    bool hasSnapshot = !_fastFuzzySnapshot.empty();
    bool hasStoredResults = (_resultCount > 0 && !_storagePath.empty());
    
    if (_task == MACH_PORT_NULL) return emptyRes;
    if (!hasSnapshot && !hasStoredResults) return emptyRes;
    
    size_t dSize = getSizeForType(type);
    size_t dSizeLocal = dSize;
    mach_port_t task = _task;
    bool isFloatType = vcore::isFloatType(type);
    bool isFloat = (type == MemDataType::Float);
    double floatTolerance = _floatTolerance;
    int filterModeLocal = filterMode;
    
    FILE* outFile = fopen(_swapPath.c_str(), "wb");
    if (!outFile) return emptyRes;
    
    size_t newResultCount = 0;
    
    // [关键修复] 使用 _resultCount 判断是否有已存储的结果，而不是读取文件后判断
    // 这与 VM 2.5.1 的逻辑一致
    if (hasStoredResults) {
        // ========== 累积筛选模式（有已存储的结果）==========
        FILE* inFile = fopen(_storagePath.c_str(), "rb");
        if (!inFile) {
            fclose(outFile);
            return emptyRes;
        }
        
        // 获取文件大小
        fseek(inFile, 0, SEEK_END);
        size_t fileSize = ftell(inFile);
        fseek(inFile, 0, SEEK_SET);
        
        size_t totalResults = fileSize / sizeof(RawResult);
        if (totalResults == 0) {
            fclose(inFile);
            fclose(outFile);
            return emptyRes;
        }
        
        std::vector<RawResult> prevResults(totalResults);
        fread(prevResults.data(), sizeof(RawResult), totalResults, inFile);
        fclose(inFile);
        
        // 按地址排序，便于批量读取
        std::sort(prevResults.begin(), prevResults.end(),
                  [](const RawResult& a, const RawResult& b) { return a.address < b.address; });
        
        // 批量读取当前值
        std::vector<uint64_t> currentValues(totalResults, 0);
        std::vector<uint8_t> readSuccess(totalResults, 0);
        
        uint64_t* currentValuesPtr = currentValues.data();
        uint8_t* readSuccessPtr = readSuccess.data();
        const RawResult* allResultsPtr = prevResults.data();
        
        // 分批并行读取
        const size_t readBatchSize = 10000;
        size_t numBatches = (totalResults + readBatchSize - 1) / readBatchSize;
        
        dispatch_apply(numBatches, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
            ^(size_t batchIdx) {
                size_t startIdx = batchIdx * readBatchSize;
                size_t endIdx = std::min(startIdx + readBatchSize, totalResults);
                
                for (size_t i = startIdx; i < endIdx; i++) {
                    uint8_t buf[8] = {0};
                    mach_vm_size_t sz = dSizeLocal;
                    if (mach_vm_read_overwrite(task, allResultsPtr[i].address, dSizeLocal,
                                               (mach_vm_address_t)buf, &sz) == KERN_SUCCESS) {
                        uint64_t val = 0;
                        memcpy(&val, buf, dSizeLocal > 8 ? 8 : dSizeLocal);
                        currentValuesPtr[i] = val;
                        readSuccessPtr[i] = 1;
                    }
                }
            });
        
        // 并行比对
        std::vector<std::vector<RawResult>> perBatchResults(numBatches);
        std::vector<std::vector<RawResult>>* perBatchResultsPtr = &perBatchResults;
        
        dispatch_apply(numBatches, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
            ^(size_t batchIdx) {
                size_t startIdx = batchIdx * readBatchSize;
                size_t endIdx = std::min(startIdx + readBatchSize, totalResults);
                
                std::vector<RawResult>& localResults = (*perBatchResultsPtr)[batchIdx];
                localResults.reserve(readBatchSize / 2);
                
                for (size_t i = startIdx; i < endIdx; i++) {
                    if (!readSuccessPtr[i]) continue;
                    
                    uint64_t oldValBits = allResultsPtr[i].value;
                    uint64_t newValBits = currentValuesPtr[i];
                    
                    bool match = false;
                    if (isFloatType) {
                        double oldVal = 0, newVal = 0;
                        if (isFloat) {
                            oldVal = *(float*)&oldValBits;
                            newVal = *(float*)&newValBits;
                        } else {
                            oldVal = *(double*)&oldValBits;
                            newVal = *(double*)&newValBits;
                        }
                        
                        if (filterModeLocal == 0) match = (newVal < oldVal - floatTolerance);
                        else if (filterModeLocal == 1) match = (newVal > oldVal + floatTolerance);
                        else if (filterModeLocal == 5) match = (fabs(newVal - oldVal) > floatTolerance);
                        else if (filterModeLocal == 6) match = (fabs(newVal - oldVal) <= floatTolerance);
                    } else {
                        int64_t oldVal = 0, newVal = 0;
                        switch (dSizeLocal) {
                            case 1: oldVal = (int8_t)oldValBits; newVal = (int8_t)newValBits; break;
                            case 2: oldVal = (int16_t)oldValBits; newVal = (int16_t)newValBits; break;
                            case 8: oldVal = (int64_t)oldValBits; newVal = (int64_t)newValBits; break;
                            default: oldVal = (int32_t)oldValBits; newVal = (int32_t)newValBits; break;
                        }
                        
                        if (filterModeLocal == 0) match = (newVal < oldVal);
                        else if (filterModeLocal == 1) match = (newVal > oldVal);
                        else if (filterModeLocal == 5) match = (newVal != oldVal);
                        else if (filterModeLocal == 6) match = (newVal == oldVal);
                    }
                    
                    if (match) {
                        localResults.push_back(makeRawResult(allResultsPtr[i].address, newValBits, type));
                    }
                }
            });
        
        // 写入结果
        for (const auto& localResults : perBatchResults) {
            if (!localResults.empty()) {
                fwrite(localResults.data(), sizeof(RawResult), localResults.size(), outFile);
                newResultCount += localResults.size();
            }
        }
    } else if (hasSnapshot) {
        // ========== 首次筛选模式（从快照）==========
        FILE* snapshotFile = fopen(_fastFuzzySnapshotPath.c_str(), "rb");
        if (!snapshotFile) {
            fclose(outFile);
            return emptyRes;
        }

        const uint64_t endAddress = 0x800000000;
        uint64_t startAddr = start;
        uint64_t endAddr = endAddress;
        std::vector<RawResult> localResults;
        localResults.reserve(65536);
        auto flushLocalResults = [&]() {
            if (!localResults.empty()) {
                fwrite(localResults.data(), sizeof(RawResult), localResults.size(), outFile);
                newResultCount += localResults.size();
                localResults.clear();
            }
        };

        for (const auto& oldRegion : _fastFuzzySnapshot) {
            if (oldRegion.start >= endAddr) continue;
            uint64_t regionEnd = oldRegion.start + oldRegion.size;
            if (regionEnd <= startAddr) continue;
            if (oldRegion.size < dSizeLocal) continue;

            std::vector<uint8_t> oldData((size_t)oldRegion.size);
            std::vector<uint8_t> currentData((size_t)oldRegion.size);
            if (fseeko(snapshotFile, (off_t)oldRegion.fileOffset, SEEK_SET) != 0) continue;
            size_t oldRead = fread(oldData.data(), 1, (size_t)oldRegion.size, snapshotFile);
            if (oldRead == 0) continue;

            mach_vm_size_t readSize = oldRegion.size;
            if (mach_vm_read_overwrite(task, oldRegion.start, oldRegion.size,
                                       (mach_vm_address_t)currentData.data(),
                                       &readSize) != KERN_SUCCESS) {
                continue;
            }

            size_t compareSize = std::min(oldRead, (size_t)readSize);
            if (compareSize < dSizeLocal) continue;

            const uint8_t* oldBytes = oldData.data();
            const uint8_t* newBytes = currentData.data();

            for (size_t offset = 0; offset + dSizeLocal <= compareSize; offset += dSizeLocal) {
                uint64_t addr = oldRegion.start + offset;
                bool match = false;
                uint64_t newValBits = 0;

                if (isFloatType) {
                    double oldVal = 0, newVal = 0;
                    if (isFloat) {
                        oldVal = *(float*)(oldBytes + offset);
                        newVal = *(float*)(newBytes + offset);
                        memcpy(&newValBits, newBytes + offset, 4);
                    } else {
                        oldVal = *(double*)(oldBytes + offset);
                        newVal = *(double*)(newBytes + offset);
                        memcpy(&newValBits, newBytes + offset, 8);
                    }
                    if (filterModeLocal == 0) match = (newVal < oldVal - floatTolerance);
                    else if (filterModeLocal == 1) match = (newVal > oldVal + floatTolerance);
                    else if (filterModeLocal == 5) match = (fabs(newVal - oldVal) > floatTolerance);
                    else if (filterModeLocal == 6) match = (fabs(newVal - oldVal) <= floatTolerance);
                } else {
                    int64_t oldVal = 0, newVal = 0;
                    switch (dSizeLocal) {
                        case 1: oldVal = *(int8_t*)(oldBytes + offset); newVal = *(int8_t*)(newBytes + offset); break;
                        case 2: oldVal = *(int16_t*)(oldBytes + offset); newVal = *(int16_t*)(newBytes + offset); break;
                        case 8: oldVal = *(int64_t*)(oldBytes + offset); newVal = *(int64_t*)(newBytes + offset); break;
                        default: oldVal = *(int32_t*)(oldBytes + offset); newVal = *(int32_t*)(newBytes + offset); break;
                    }
                    memcpy(&newValBits, newBytes + offset, dSizeLocal > 8 ? 8 : dSizeLocal);
                    if (filterModeLocal == 0) match = (newVal < oldVal);
                    else if (filterModeLocal == 1) match = (newVal > oldVal);
                    else if (filterModeLocal == 5) match = (newVal != oldVal);
                    else if (filterModeLocal == 6) match = (newVal == oldVal);
                }

                if (match) {
                    localResults.push_back(makeRawResult(addr, newValBits, type));
                    if (localResults.size() >= 65536) {
                        flushLocalResults();
                    }
                }
            }
        }
        flushLocalResults();
        fclose(snapshotFile);
    }
    
    fclose(outFile);
    
    if (newResultCount == 0) {
        remove(_swapPath.c_str());
        _resultCount = 0;
    } else {
        remove(_storagePath.c_str());
        rename(_swapPath.c_str(), _storagePath.c_str());
        _resultCount = newResultCount;
    }
    
    // [关键] 首次筛选后清除全内存快照，节省内存
    // 后续筛选使用存储的结果值进行比对，不需要快照
    if (!_fastFuzzySnapshot.empty()) {
        clearFastFuzzySnapshot();
    }
    
    return getResults(0, 100);
}

} // namespace vcore
