/**
 * VansonLoader L2.3 - Memory Types
 * 内存搜索数据类型定义 (简化版)
 */

#ifndef VLMemTypes_hpp
#define VLMemTypes_hpp

#include <cstdint>
#include <string>
#include <vector>

namespace vcore {

// 数据类型枚举
enum class MemDataType : uint8_t {
    Int8 = 0,
    Int16 = 1,
    Int32 = 2,
    Int64 = 3,
    UInt8 = 4,
    UInt16 = 5,
    UInt32 = 6,
    UInt64 = 7,
    Float = 8,
    Double = 9,
    String = 10,
    IntAuto = 11,
    UIntAuto = 12,
    FloatAuto = 13
};

// 搜索模式
enum class SearchMode : uint8_t {
    Exact = 0,
    Fuzzy = 1,
    Group = 2,
    Between = 3
};

// 模糊搜索类型
enum class FuzzyType : uint8_t {
    Less = 0,
    Greater = 1,
    Between = 2,
    IncreasedBy = 3,
    DecreasedBy = 4,
    Changed = 5,
    Unchanged = 6
};

// 筛选模式
enum class FilterMode : uint8_t {
    Less = 0,
    Greater = 1,
    Between = 2,
    Increased = 3,
    Decreased = 4,
    Changed = 5,
    Unchanged = 6
};

// 搜索结果
struct ScanResult {
    uint64_t address;
    MemDataType type;
    union {
        int8_t i8;
        int16_t i16;
        int32_t i32;
        int64_t i64;
        uint8_t u8;
        uint16_t u16;
        uint32_t u32;
        uint64_t u64;
        float f;
        double d;
    } value;
};

// 内存区域
struct MemRegion {
    uint64_t start;
    uint64_t end;
    bool isWritable;
    bool isExecutable;
};

// 联合搜索项
struct GroupItem {
    MemDataType type;
    union {
        int8_t i8;
        int16_t i16;
        int32_t i32;
        int64_t i64;
        uint8_t u8;
        uint16_t u16;
        uint32_t u32;
        uint64_t u64;
        float f;
        double d;
    } value;
    bool relative;
    bool isWildcard;
    uint64_t skipBytes;
};

// 快照区域
struct SnapshotRegion {
    uint64_t start;
    uint32_t size;
    std::vector<uint8_t> data;
};

// 差异区域
struct DiffRegion {
    uint64_t address;
    uint32_t size;
};

// 搜索进度
struct SearchProgress {
    int level;
    size_t foundCount;
};

// 进度回调
typedef void (*ProgressCallback)(SearchProgress progress, void* userData);

// 辅助函数
inline size_t getSizeForType(MemDataType type) {
    switch (type) {
        case MemDataType::Int8:
        case MemDataType::UInt8:
            return 1;
        case MemDataType::Int16:
        case MemDataType::UInt16:
            return 2;
        case MemDataType::Int32:
        case MemDataType::UInt32:
        case MemDataType::Float:
            return 4;
        case MemDataType::Int64:
        case MemDataType::UInt64:
        case MemDataType::Double:
            return 8;
        default:
            return 4;
    }
}

inline bool isFloatType(MemDataType type) {
    return type == MemDataType::Float || 
           type == MemDataType::Double || 
           type == MemDataType::FloatAuto;
}

inline bool isAutoType(MemDataType type) {
    return type == MemDataType::IntAuto || 
           type == MemDataType::UIntAuto || 
           type == MemDataType::FloatAuto;
}

inline std::vector<MemDataType> getSubTypesForAuto(MemDataType autoType) {
    std::vector<MemDataType> subTypes;
    switch (autoType) {
        case MemDataType::IntAuto:
            subTypes = {MemDataType::Int8, MemDataType::Int16, 
                       MemDataType::Int32, MemDataType::Int64};
            break;
        case MemDataType::UIntAuto:
            subTypes = {MemDataType::UInt8, MemDataType::UInt16, 
                       MemDataType::UInt32, MemDataType::UInt64};
            break;
        case MemDataType::FloatAuto:
            subTypes = {MemDataType::Float, MemDataType::Double};
            break;
        default:
            break;
    }
    return subTypes;
}

} // namespace vcore

#endif /* VLMemTypes_hpp */
