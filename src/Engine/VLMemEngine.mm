/**
 * VansonLoader L2.3 - Memory Engine Implementation
 * ObjC 桥接层实现 (简化版：仅内存搜索)
 */

#import "VLMemEngine.h"
#import "../Core/VLMemCore.hpp"
#import <mach-o/dyld.h>
#include <memory>
#include <cmath>

@implementation VLMemResultItem
@end
@implementation VLMemTimelineItem
@end
@implementation VLMemWriteUndoItem
@end

@interface VLMemEngine () {
    std::unique_ptr<vcore::MemCore> _core;
}
@property (nonatomic, copy) NSString *resultFilePath;
@property (nonatomic, strong) NSMutableArray<VLMemTimelineItem *> *timeline;
@property (nonatomic, strong) NSMutableArray<VLMemWriteUndoItem *> *manualWriteUndoStack;
@end

@implementation VLMemEngine

+ (instancetype)shared {
    static VLMemEngine *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[VLMemEngine alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _core = std::make_unique<vcore::MemCore>();
        
        NSString *tmpDir = NSTemporaryDirectory();
        NSString *pathA = [tmpDir stringByAppendingPathComponent:@"vmem_scan_a.bin"];
        NSString *pathB = [tmpDir stringByAppendingPathComponent:@"vmem_scan_b.bin"];
        _core->setStoragePath([pathA UTF8String], [pathB UTF8String]);
        _resultFilePath = [pathA copy];
        _timeline = [NSMutableArray array];
        _manualWriteUndoStack = [NSMutableArray array];
        
        _core->setFloatTolerance(0.001);
        _core->setGroupSearchRange(200);
        _core->setGroupAnchorMode(false);
    }
    return self;
}

- (void)dealloc {
    if (_core) {
        _core->clearResults();
    }
    [self clearTimeline];
    [self clearManualWriteUndo];
    NSString *tmpDir = NSTemporaryDirectory();
    [[NSFileManager defaultManager] removeItemAtPath:[tmpDir stringByAppendingPathComponent:@"vmem_scan_a.bin"] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[tmpDir stringByAppendingPathComponent:@"vmem_scan_b.bin"] error:nil];
}

- (void)initialize {
    static dispatch_once_t initOnce;
    dispatch_once(&initOnce, ^{
        _core->init();
        

    });
}

- (BOOL)isReady {
    return _core && _core->isReady();
}

#pragma mark - 配置

- (void)setFloatTolerance:(double)floatTolerance {
    _floatTolerance = floatTolerance;
    _core->setFloatTolerance(floatTolerance);
}

- (void)setGroupSearchRange:(uint64_t)groupSearchRange {
    _groupSearchRange = groupSearchRange;
    _core->setGroupSearchRange(groupSearchRange);
}

- (void)setGroupAnchorMode:(BOOL)groupAnchorMode {
    _groupAnchorMode = groupAnchorMode;
    _core->setGroupAnchorMode(groupAnchorMode);
}

- (void)setResultLimit:(NSUInteger)resultLimit {
    _resultLimit = resultLimit;
    _core->setResultLimit(resultLimit);
}

#pragma mark - 类型转换

static vcore::MemDataType toMemDataType(VMemDataType type) {
    return static_cast<vcore::MemDataType>(type);
}

#pragma mark - 内存搜索

- (void)scanWithMode:(VMemSearchMode)mode
              value:(NSString *)valueStr
               type:(VMemDataType)type
         completion:(void (^)(NSUInteger, NSString *))completion {
    [self scanWithMode:mode
                 value:valueStr
                  type:type
            rangeStart:0
              rangeEnd:0
            completion:completion];
}

- (void)scanWithMode:(VMemSearchMode)mode
              value:(NSString *)valueStr
               type:(VMemDataType)type
         rangeStart:(uint64_t)start
           rangeEnd:(uint64_t)end
         completion:(void (^)(NSUInteger, NSString *))completion {
    
    if (!_core->isReady()) {
        if (completion) completion(0, @"Engine not initialized");
        return;
    }
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        vcore::MemDataType coreType = toMemDataType(type);
        std::string cValStr = [valueStr UTF8String] ?: "";
        
        self->_core->scan(coreType, cValStr, (int)mode, start, end);
        NSUInteger count = self->_core->getResultCount();
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                NSString *msg = count > 0 ? @"Search completed" : @"No results found";
                completion(count, msg);
            }
        });
    });
}

- (void)nextScanWithValue:(NSString *)valueStr
                     type:(VMemDataType)type
               filterMode:(VMemFilterMode)mode
               completion:(void (^)(NSUInteger, NSString *))completion {
    
    if (!_core->isReady()) {
        if (completion) completion(0, @"Engine not initialized");
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        vcore::MemDataType coreType = toMemDataType(type);
        std::string cValStr = [valueStr UTF8String] ?: "";
        
        int searchMode = 6;
        switch (mode) {
            case VMemFilterModeDecreased: searchMode = 0; break;
            case VMemFilterModeIncreased: searchMode = 1; break;
            case VMemFilterModeChanged: searchMode = 5; break;
            case VMemFilterModeUnchanged: searchMode = 6; break;
            default: searchMode = 100; break;
        }
        
        self->_core->nextScan(coreType, cValStr, searchMode);
        NSUInteger count = self->_core->getResultCount();
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                NSString *msg = count > 0 ? @"Filter completed" : @"No results found";
                completion(count, msg);
            }
        });
    });
}

- (void)scanNearbyWithValue:(NSString *)valueStr
                       type:(VMemDataType)type
                      range:(uint64_t)range
                 completion:(void (^)(NSUInteger, NSString *))completion {
    
    if (!_core->isReady()) {
        if (completion) completion(0, @"Engine not initialized");
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        vcore::MemDataType coreType = toMemDataType(type);
        std::string cValStr = [valueStr UTF8String] ?: "";
        
        self->_core->scanNearby(coreType, cValStr, range);
        NSUInteger count = self->_core->getResultCount();
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                NSString *msg = count > 0 ? @"Nearby search completed" : @"No results found";
                completion(count, msg);
            }
        });
    });
}

- (void)filterResultsWithMode:(VMemFilterMode)mode
                        val1:(NSString *)v1
                        val2:(NSString *)v2
                        type:(VMemDataType)type
                  completion:(void (^)(NSUInteger, NSString *))completion {
    
    if (!_core->isReady()) {
        if (completion) completion(0, @"Engine not initialized");
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        vcore::MemDataType coreType = toMemDataType(type);
        vcore::FilterMode coreMode = static_cast<vcore::FilterMode>(mode);
        std::string s1 = [v1 UTF8String] ?: "";
        std::string s2 = [v2 UTF8String] ?: "";
        
        self->_core->filterResults(coreMode, coreType, s1, s2);
        NSUInteger count = self->_core->getResultCount();
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                NSString *msg = count > 0 ? @"Filter completed" : @"No results found";
                completion(count, msg);
            }
        });
    });
}

#pragma mark - 结果管理

- (NSUInteger)resultCount {
    return _core->getResultCount();
}

- (VMemResultItem *)getResultAtIndex:(NSUInteger)index type:(VMemDataType)type {
    if (index >= _core->getResultCount()) return nil;
    
    auto results = _core->getResults(index, 1);
    if (results.empty()) return nil;
    
    auto& cppItem = results[0];
    VMemResultItem *item = [VMemResultItem new];
    item.address = cppItem.address;
    item.type = (VMemDataType)cppItem.type;
    
    size_t sz = vcore::getSizeForType(cppItem.type);
    if (cppItem.type == vcore::MemDataType::String) {
        // String: read up to 128 bytes from memory
        uint8_t strBuf[129] = {0};
        size_t readLen = 128;
        if (_core->readMem(cppItem.address, strBuf, readLen)) {
            strBuf[128] = 0;
            size_t len = strnlen((char*)strBuf, 128);
            NSString *str = [[NSString alloc] initWithBytes:strBuf length:len encoding:NSUTF8StringEncoding];
            if (!str) {
                // Fallback: try ASCII, replace non-printable
                NSMutableString *ascii = [NSMutableString string];
                for (size_t i = 0; i < len && i < 128; i++) {
                    uint8_t c = strBuf[i];
                    if (c >= 32 && c < 127) [ascii appendFormat:@"%c", c];
                    else [ascii appendString:@"."];
                }
                str = ascii;
            }
            item.valueStr = str;
        } else {
            item.valueStr = @"(Err)";
        }
        item.prevValue = @(0);
    } else if (vcore::isFloatType(cppItem.type)) {
        uint8_t valueBuf[8] = {0};
        if (!_core->readMem(cppItem.address, valueBuf, sz)) {
            memcpy(valueBuf, &cppItem.value, sz > 8 ? 8 : sz);
        }
        double val;
        if (sz == 4) {
            float temp;
            memcpy(&temp, valueBuf, 4);
            val = temp;
        } else {
            memcpy(&val, valueBuf, 8);
        }
        item.prevValue = @(val);
        item.valueStr = [NSString stringWithFormat:@"%.4f", val];
    } else {
        uint8_t valueBuf[8] = {0};
        if (!_core->readMem(cppItem.address, valueBuf, sz)) {
            memcpy(valueBuf, &cppItem.value, sz > 8 ? 8 : sz);
        }
        long long val = 0;
        memcpy(&val, valueBuf, sz > 8 ? 8 : sz);
        item.prevValue = @(val);
        item.valueStr = [NSString stringWithFormat:@"%lld", val];
    }
    
    return item;
}

- (void)removeResultAtIndex:(NSUInteger)index {
    _core->removeResult(index);
}

- (void)clearResults {
    _core->clearResults();
    [self clearTimeline];
    [self clearManualWriteUndo];
}

- (NSString *)timelineSnapshotPath {
    NSString *uuid = [[NSUUID UUID] UUIDString];
    NSString *name = [NSString stringWithFormat:@"vl_timeline_%@.bin", uuid];
    return [NSTemporaryDirectory() stringByAppendingPathComponent:name];
}

- (NSArray<VLMemTimelineItem *> *)timelineItems {
    return [self.timeline copy];
}

- (void)trimTimelineIfNeeded {
    const NSUInteger maxItems = 20;
    NSFileManager *fm = [NSFileManager defaultManager];
    while (self.timeline.count > maxItems) {
        VLMemTimelineItem *old = self.timeline.lastObject;
        if (old.filePath.length > 0) {
            [fm removeItemAtPath:old.filePath error:nil];
        }
        [self.timeline removeLastObject];
    }
}

- (void)captureTimelineWithTitle:(NSString *)title
                           detail:(NSString *)detail
                         dataType:(VMemDataType)type {
    if (self.resultCount == 0 || self.resultFilePath.length == 0) return;

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:self.resultFilePath]) return;

    NSString *snapPath = [self timelineSnapshotPath];
    if (![fm copyItemAtPath:self.resultFilePath toPath:snapPath error:nil]) return;

    VLMemTimelineItem *item = [VLMemTimelineItem new];
    item.title = title ?: @"";
    item.detail = detail ?: @"";
    item.filePath = snapPath;
    item.resultCount = self.resultCount;
    item.dataType = type;
    item.date = [NSDate date];
    [self.timeline insertObject:item atIndex:0];
    [self trimTimelineIfNeeded];
}

- (BOOL)restoreTimelineAtIndex:(NSUInteger)index {
    if (index >= self.timeline.count) return NO;
    VLMemTimelineItem *item = self.timeline[index];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (item.filePath.length == 0 || ![fm fileExistsAtPath:item.filePath]) return NO;

    NSString *copyPath = [self timelineSnapshotPath];
    if (![fm copyItemAtPath:item.filePath toPath:copyPath error:nil]) return NO;

    BOOL ok = _core->restoreResultsFromFile([copyPath UTF8String], item.resultCount);
    if (!ok) [fm removeItemAtPath:copyPath error:nil];
    return ok;
}

- (void)removeTimelineAtIndex:(NSUInteger)index {
    if (index >= self.timeline.count) return;
    VLMemTimelineItem *item = self.timeline[index];
    if (item.filePath.length > 0) {
        [[NSFileManager defaultManager] removeItemAtPath:item.filePath error:nil];
    }
    [self.timeline removeObjectAtIndex:index];
}

- (void)clearTimeline {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (VLMemTimelineItem *item in self.timeline) {
        if (item.filePath.length > 0) {
            [fm removeItemAtPath:item.filePath error:nil];
        }
    }
    [self.timeline removeAllObjects];
}

- (void)rememberManualWriteUndoAtAddress:(uint64_t)address
                                    type:(VMemDataType)type
                                oldValue:(NSString *)oldValue
                                 oldData:(NSData *)oldData
                                newValue:(NSString *)newValue {
    if (!oldData || oldData.length == 0) return;

    VLMemWriteUndoItem *item = [VLMemWriteUndoItem new];
    item.address = address;
    item.type = type;
    item.oldValue = oldValue ?: @"";
    item.writtenValue = newValue ?: @"";
    item.oldData = oldData;
    item.date = [NSDate date];
    [self.manualWriteUndoStack insertObject:item atIndex:0];

    const NSUInteger maxItems = 30;
    while (self.manualWriteUndoStack.count > maxItems) {
        [self.manualWriteUndoStack removeLastObject];
    }
}

- (VLMemWriteUndoItem *)lastManualWriteUndoForAddress:(uint64_t)address
                                                 type:(VMemDataType)type {
    for (VLMemWriteUndoItem *item in self.manualWriteUndoStack) {
        if (item.address == address && item.type == type) return item;
    }
    return nil;
}

- (BOOL)undoLastManualWriteForAddress:(uint64_t)address type:(VMemDataType)type {
    VLMemWriteUndoItem *item = [self lastManualWriteUndoForAddress:address type:type];
    if (!item) return NO;
    BOOL ok = [self writeMemory:address data:item.oldData];
    if (ok) [self.manualWriteUndoStack removeObject:item];
    return ok;
}

- (void)clearManualWriteUndo {
    [self.manualWriteUndoStack removeAllObjects];
}

- (void)batchModifyWithValue:(NSString *)value
                       limit:(NSInteger)limit
                        type:(VMemDataType)type
                        mode:(int)mode {
    vcore::MemDataType coreType = toMemDataType(type);
    std::string cVal = [value UTF8String] ?: "";
    _core->batchModify(cVal, (int)limit, coreType, mode);
}

#pragma mark - 内存读写

- (NSString *)readAddress:(uint64_t)address type:(VMemDataType)type {
    if (address < 0x10000 || address > 0x800000000000ULL) return @"(Null)";
    
    uint8_t buf[8] = {0};
    size_t sz = vcore::getSizeForType(toMemDataType(type));
    
    if (!_core->readMem(address, buf, sz)) return @"(Err)";
    
    switch (type) {
        case VMemDataTypeI8:  return [NSString stringWithFormat:@"%d", *(int8_t*)buf];
        case VMemDataTypeU8:  return [NSString stringWithFormat:@"%u", *(uint8_t*)buf];
        case VMemDataTypeI16: return [NSString stringWithFormat:@"%d", *(int16_t*)buf];
        case VMemDataTypeU16: return [NSString stringWithFormat:@"%u", *(uint16_t*)buf];
        case VMemDataTypeI32: return [NSString stringWithFormat:@"%d", *(int32_t*)buf];
        case VMemDataTypeU32: return [NSString stringWithFormat:@"%u", *(uint32_t*)buf];
        case VMemDataTypeI64: return [NSString stringWithFormat:@"%lld", *(int64_t*)buf];
        case VMemDataTypeU64: return [NSString stringWithFormat:@"%llu", *(uint64_t*)buf];
        case VMemDataTypeF32: return [NSString stringWithFormat:@"%.4f", *(float*)buf];
        case VMemDataTypeF64: return [NSString stringWithFormat:@"%.4lf", *(double*)buf];
        case VMemDataTypeString: {
            uint8_t strBuf[129] = {0};
            if (_core->readMem(address, strBuf, 128)) {
                strBuf[128] = 0;
                size_t len = strnlen((char*)strBuf, 128);
                NSString *str = [[NSString alloc] initWithBytes:strBuf length:len encoding:NSUTF8StringEncoding];
                if (!str) {
                    NSMutableString *ascii = [NSMutableString string];
                    for (size_t i = 0; i < len && i < 128; i++) {
                        uint8_t c = strBuf[i];
                        if (c >= 32 && c < 127) [ascii appendFormat:@"%c", c];
                        else [ascii appendString:@"."];
                    }
                    str = ascii;
                }
                return str.length > 0 ? str : @"(empty)";
            }
            return @"(Err)";
        }
        default: return @"?";
    }
}

- (BOOL)writeAddress:(uint64_t)address value:(NSString *)value type:(VMemDataType)type {
    if (!value || value.length == 0) return NO;
    if (address < 0x10000 || address > 0x800000000000ULL) return NO;
    
    uint8_t buf[8] = {0};
    size_t sz = vcore::getSizeForType(toMemDataType(type));
    
    switch (type) {
        case VMemDataTypeI8:  { int8_t v = [value intValue]; memcpy(buf, &v, 1); break; }
        case VMemDataTypeU8:  { uint8_t v = [value intValue]; memcpy(buf, &v, 1); break; }
        case VMemDataTypeI16: { int16_t v = [value intValue]; memcpy(buf, &v, 2); break; }
        case VMemDataTypeU16: { uint16_t v = [value intValue]; memcpy(buf, &v, 2); break; }
        case VMemDataTypeI32: { int32_t v = [value intValue]; memcpy(buf, &v, 4); break; }
        case VMemDataTypeU32: { uint32_t v = (uint32_t)[value longLongValue]; memcpy(buf, &v, 4); break; }
        case VMemDataTypeI64: { int64_t v = [value longLongValue]; memcpy(buf, &v, 8); break; }
        case VMemDataTypeU64: { uint64_t v = strtoull([value UTF8String], NULL, 10); memcpy(buf, &v, 8); break; }
        case VMemDataTypeF32: { float v = [value floatValue]; memcpy(buf, &v, 4); break; }
        case VMemDataTypeF64: { double v = [value doubleValue]; memcpy(buf, &v, 8); break; }
        case VMemDataTypeString: {
            const char *cstr = [value UTF8String];
            size_t len = strlen(cstr);
            return _core->writeMem(address, cstr, len);
        }
        default: return NO;
    }
    
    return _core->writeMem(address, buf, sz);
}

- (NSData *)readMemory:(uint64_t)address length:(size_t)length {
    if (address == 0 || length == 0) return nil;
    
    void *buffer = malloc(length);
    if (!buffer) return nil;
    
    if (_core->readMem(address, buffer, length)) {
        return [NSData dataWithBytesNoCopy:buffer length:length freeWhenDone:YES];
    }
    
    free(buffer);
    return nil;
}

- (BOOL)writeMemory:(uint64_t)address data:(NSData *)data {
    if (address == 0 || !data || data.length == 0) return NO;
    return _core->writeMem(address, data.bytes, data.length);
}

#pragma mark - 特征码搜索

- (void)scanSignature:(NSString *)signature
           rangeStart:(uint64_t)start
             rangeEnd:(uint64_t)end
           completion:(void (^)(NSArray<VMemResultItem *> *))completion {
    
    if (!_core->isReady() || !signature || signature.length == 0) {
        if (completion) completion(@[]);
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        auto results = self->_core->scanSignature([signature UTF8String], start, end);
        
        NSMutableArray<VMemResultItem *> *items = [NSMutableArray array];
        for (const auto& res : results) {
            VMemResultItem *item = [VMemResultItem new];
            item.address = res.address;
            item.type = VMemDataTypeI8;
            [items addObject:item];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(items);
        });
    });
}

#pragma mark - 快速模糊搜索

- (void)fastFuzzyInitWithCompletion:(void (^)(BOOL, NSString *, NSUInteger))completion {
    if (!_core->isReady()) {
        if (completion) completion(NO, @"Engine not initialized", 0);
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        self->_core->fastFuzzyInit();
        NSUInteger count = self->_core->getFastFuzzyAddressCount();
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(YES, @"Snapshot created", count);
            }
        });
    });
}

- (BOOL)hasFastFuzzySnapshot {
    return _core->hasFastFuzzySnapshot();
}

- (void)fastFuzzyFilterWithMode:(VMemFilterMode)mode
                           type:(VMemDataType)type
                     completion:(void (^)(NSUInteger, NSString *))completion {
    
    if (!_core->isReady()) {
        if (completion) completion(0, @"Engine not initialized");
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        vcore::MemDataType coreType = toMemDataType(type);
        
        // 映射ObjC层的VMemFilterMode到C++层的filterMode
        // C++层: 0=变小, 1=变大, 5=变化, 6=无变化
        // ObjC层: VMemFilterModeIncreased=3, VMemFilterModeDecreased=4, VMemFilterModeChanged=5, VMemFilterModeUnchanged=6
        int filterMode = 5; // 默认变化
        switch (mode) {
            case VMemFilterModeDecreased: filterMode = 0; break;  // 变小
            case VMemFilterModeIncreased: filterMode = 1; break;  // 变大
            case VMemFilterModeChanged:   filterMode = 5; break;  // 变化
            case VMemFilterModeUnchanged: filterMode = 6; break;  // 无变化
            default: filterMode = 5; break;
        }
        
        self->_core->fastFuzzyFilter(coreType, filterMode, 0, 0);
        NSUInteger count = self->_core->getResultCount();
        NSString *tmpDir = NSTemporaryDirectory();
        self.resultFilePath =
            count > 0 ? [tmpDir stringByAppendingPathComponent:@"vmem_scan_a.bin"] : nil;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                NSString *msg = count > 0 ? @"Filter completed" : @"No results found";
                completion(count, msg);
            }
        });
    });
}

- (void)clearFastFuzzySnapshot {
    _core->clearFastFuzzySnapshot();
}

#pragma mark - 快照

- (void)takeSnapshot {
    _core->takeSnapshot(512 * 1024 * 1024);
}

- (void)clearSnapshot {
    _core->clearSnapshot();
}

- (void)saveBaselineSnapshot {
    _core->saveBaselineSnapshot();
}

- (void)clearBaselineSnapshot {
    _core->clearBaselineSnapshot();
}

- (BOOL)hasBaselineSnapshot {
    return _core->hasBaselineSnapshot();
}

@end
