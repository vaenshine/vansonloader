/**
 * VansonLoader L2.3 - Memory Core
 * 内存搜索引擎核心 (简化版：仅内存搜索)
 */

#ifndef VLMemCore_hpp
#define VLMemCore_hpp

#include "VLMemTypes.hpp"
#include <functional>
#include <mach/mach.h>
#include <string>
#include <vector>

namespace vcore {

// 特征码数据
struct SignatureData {
    std::vector<uint8_t> bytes;
    std::vector<bool> mask;
    size_t length;
    int firstValidIndex;
    uint8_t firstValidByte;
};

class MemCore {
public:
    MemCore();
    ~MemCore();
    
    // ========== 初始化 ==========
    void init();
    bool isReady() const { return _task != MACH_PORT_NULL; }
    
    // ========== 内存读写 ==========
    bool readMem(uint64_t address, void* buffer, size_t size);
    bool writeMem(uint64_t address, const void* buffer, size_t size);
    
    // ========== 快照系统 ==========
    void takeSnapshot(uint64_t maxTotalSize = 1024 * 1024 * 1024);
    void takeSnapshot(uint64_t maxTotalSize, uint64_t priorityStart, uint64_t priorityEnd);
    const std::vector<SnapshotRegion>& getSnapshot() const { return _snapshot; }
    void clearSnapshot();
    
    // ========== 内存搜索 ==========
    std::vector<ScanResult> scan(MemDataType type, const std::string& valueStr,
                                 int searchMode, uint64_t start = 0, uint64_t end = 0);
    std::vector<ScanResult> nextScan(MemDataType type, const std::string& valueStr, int searchMode);
    std::vector<ScanResult> scanNearby(MemDataType type, const std::string& valueStr, uint64_t range);
    
    // ========== 结果管理 ==========
    size_t filterResults(FilterMode mode, MemDataType type, 
                        const std::string& v1, const std::string& v2);
    bool removeResult(size_t index);
    void batchModify(const std::string& input, int limit, MemDataType type, int mode);
    
    std::vector<ScanResult> getResults(size_t start, size_t count);
    size_t getResultCount() const { return _resultCount; }
    void clearResults() { _resultCount = 0; }
    
    // ========== 配置 ==========
    void setResultLimit(size_t limit) { _resultLimit = limit; }
    size_t getResultLimit() const { return _resultLimit; }
    
    void setFloatTolerance(double tolerance) { _floatTolerance = tolerance; }
    double getFloatTolerance() const { return _floatTolerance; }
    
    void setGroupSearchRange(uint64_t range) { _groupSearchRange = range; }
    uint64_t getGroupSearchRange() const { return _groupSearchRange; }
    
    void setGroupAnchorMode(bool enabled) { _groupAnchorMode = enabled; }
    bool getGroupAnchorMode() const { return _groupAnchorMode; }
    
    void setStoragePath(const std::string& path, const std::string& swapPath);
    bool restoreResultsFromFile(const std::string& filePath, size_t resultCount);
    
    // ========== 特征码搜索 ==========
    SignatureData parseSignature(const std::string& sig);
    std::vector<ScanResult> scanSignature(const std::string& sig, uint64_t start, uint64_t end);
    
    // ========== 增量快照 ==========
    void saveBaselineSnapshot();
    void clearBaselineSnapshot();
    bool hasBaselineSnapshot() const { return !_baselineSnapshot.empty(); }
    std::vector<DiffRegion> compareWithBaseline(uint64_t minChangeSize = 8);
    
    // ========== 快速模糊搜索 ==========
    struct FastFuzzySnapshotRegion {
        uint64_t start;
        uint64_t size;
        uint64_t fileOffset;
    };

    void fastFuzzyInit();
    size_t getFastFuzzyAddressCount() const;
    bool hasFastFuzzySnapshot() const { return !_fastFuzzySnapshot.empty() || _resultCount > 0; }
    std::vector<ScanResult> fastFuzzyFilter(MemDataType type, int filterMode,
                                            uint64_t start = 0, uint64_t end = 0);
    void clearFastFuzzySnapshot();
    void updateFastFuzzySnapshotFromResults(MemDataType type);  // 基于筛选结果更新快照
    
    // ========== 辅助函数 ==========
    std::vector<GroupItem> parseGroupString(const std::string& groupStr,
                                            MemDataType defaultType, uint64_t& outRange);
    void parseRangeString(const std::string& rangeStr, MemDataType type,
                         void* minVal, void* maxVal);
    
private:
    mach_port_t _task;
    size_t _resultLimit;
    double _floatTolerance;
    uint64_t _groupSearchRange;
    bool _groupAnchorMode;
    
    std::string _storagePath;
    std::string _swapPath;
    std::string _fastFuzzySnapshotPath;
    size_t _resultCount;
    size_t _fastFuzzyAddressCount = 0;
    
    std::vector<SnapshotRegion> _snapshot;
    std::vector<SnapshotRegion> _baselineSnapshot;
    std::vector<FastFuzzySnapshotRegion> _fastFuzzySnapshot;
    
    void parseValue(const std::string& valStr, MemDataType type, void* outVal);
};

} // namespace vcore

#endif /* VLMemCore_hpp */
