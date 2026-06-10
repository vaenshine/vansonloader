/**
 * VansonLoader L2.3 - Memory Engine (ObjC Bridge)
 * 内存搜索引擎 ObjC 接口
 * 简化版：仅保留内存搜索功能
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 数据类型枚举
typedef NS_ENUM(NSUInteger, VMemDataType) {
    VMemDataTypeI8 = 0,
    VMemDataTypeI16 = 1,
    VMemDataTypeI32 = 2,
    VMemDataTypeI64 = 3,
    VMemDataTypeU8 = 4,
    VMemDataTypeU16 = 5,
    VMemDataTypeU32 = 6,
    VMemDataTypeU64 = 7,
    VMemDataTypeF32 = 8,
    VMemDataTypeF64 = 9,
    VMemDataTypeString = 10,
    VMemDataTypeIntAuto = 11,
    VMemDataTypeUIntAuto = 12,
    VMemDataTypeFloatAuto = 13
};

// 搜索模式
typedef NS_ENUM(NSUInteger, VMemSearchMode) {
    VMemSearchModeExact = 0,
    VMemSearchModeFuzzy = 1,
    VMemSearchModeGroup = 2,
    VMemSearchModeBetween = 3
};

// 筛选模式
typedef NS_ENUM(NSUInteger, VMemFilterMode) {
    VMemFilterModeLess = 0,
    VMemFilterModeGreater = 1,
    VMemFilterModeBetween = 2,
    VMemFilterModeIncreased = 3,
    VMemFilterModeDecreased = 4,
    VMemFilterModeChanged = 5,
    VMemFilterModeUnchanged = 6
};

// 搜索结果项
@interface VLMemResultItem : NSObject
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, assign) VMemDataType type;
@property (nonatomic, copy, nullable) NSString *valueStr;
@property (nonatomic, strong, nullable) NSNumber *prevValue;
@end

@interface VLMemTimelineItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, assign) NSUInteger resultCount;
@property (nonatomic, assign) VMemDataType dataType;
@end

@interface VLMemWriteUndoItem : NSObject
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, assign) VMemDataType type;
@property (nonatomic, copy) NSString *oldValue;
@property (nonatomic, copy) NSString *writtenValue;
@property (nonatomic, strong) NSData *oldData;
@property (nonatomic, strong) NSDate *date;
@end

// Backward compatibility
typedef VLMemResultItem VMemResultItem;

// 内存引擎
@interface VLMemEngine : NSObject

+ (instancetype)shared;

#pragma mark - 初始化

- (void)initialize;

@property (nonatomic, readonly) BOOL isReady;

#pragma mark - 配置

@property (nonatomic, assign) double floatTolerance;
@property (nonatomic, assign) uint64_t groupSearchRange;
@property (nonatomic, assign) BOOL groupAnchorMode;
@property (nonatomic, assign) NSUInteger resultLimit;

#pragma mark - 内存搜索

- (void)scanWithMode:(VMemSearchMode)mode
              value:(NSString *)valueStr
               type:(VMemDataType)type
         completion:(void (^)(NSUInteger count, NSString *msg))completion;

- (void)scanWithMode:(VMemSearchMode)mode
              value:(NSString *)valueStr
               type:(VMemDataType)type
         rangeStart:(uint64_t)start
           rangeEnd:(uint64_t)end
         completion:(void (^)(NSUInteger count, NSString *msg))completion;

- (void)nextScanWithValue:(NSString *)valueStr
                     type:(VMemDataType)type
               filterMode:(VMemFilterMode)mode
               completion:(void (^)(NSUInteger count, NSString *msg))completion;

- (void)scanNearbyWithValue:(NSString *)valueStr
                       type:(VMemDataType)type
                      range:(uint64_t)range
                 completion:(void (^)(NSUInteger count, NSString *msg))completion;

- (void)filterResultsWithMode:(VMemFilterMode)mode
                        val1:(NSString *)v1
                        val2:(NSString *)v2
                        type:(VMemDataType)type
                  completion:(void (^)(NSUInteger count, NSString *msg))completion;

#pragma mark - 结果管理

@property (nonatomic, readonly) NSUInteger resultCount;

- (nullable VLMemResultItem *)getResultAtIndex:(NSUInteger)index type:(VMemDataType)type;
- (void)removeResultAtIndex:(NSUInteger)index;
- (void)clearResults;

- (NSArray<VLMemTimelineItem *> *)timelineItems;
- (void)captureTimelineWithTitle:(NSString *)title
                           detail:(NSString *)detail
                         dataType:(VMemDataType)type;
- (BOOL)restoreTimelineAtIndex:(NSUInteger)index;
- (void)removeTimelineAtIndex:(NSUInteger)index;
- (void)clearTimeline;

- (void)rememberManualWriteUndoAtAddress:(uint64_t)address
                                    type:(VMemDataType)type
                                oldValue:(NSString *)oldValue
                                 oldData:(NSData *)oldData
                                newValue:(NSString *)newValue;
- (nullable VLMemWriteUndoItem *)lastManualWriteUndoForAddress:(uint64_t)address
                                                          type:(VMemDataType)type;
- (BOOL)undoLastManualWriteForAddress:(uint64_t)address type:(VMemDataType)type;
- (void)clearManualWriteUndo;

- (void)batchModifyWithValue:(NSString *)value
                       limit:(NSInteger)limit
                        type:(VMemDataType)type
                        mode:(int)mode;

#pragma mark - 内存读写

- (nullable NSString *)readAddress:(uint64_t)address type:(VMemDataType)type;
- (BOOL)writeAddress:(uint64_t)address value:(NSString *)value type:(VMemDataType)type;
- (nullable NSData *)readMemory:(uint64_t)address length:(size_t)length;
- (BOOL)writeMemory:(uint64_t)address data:(NSData *)data;

#pragma mark - 特征码搜索

- (void)scanSignature:(NSString *)signature
           rangeStart:(uint64_t)start
             rangeEnd:(uint64_t)end
           completion:(void (^)(NSArray<VLMemResultItem *> *results))completion;

#pragma mark - 快速模糊搜索

- (void)fastFuzzyInitWithCompletion:(void (^)(BOOL success, NSString *msg, NSUInteger addressCount))completion;
- (BOOL)hasFastFuzzySnapshot;
- (void)fastFuzzyFilterWithMode:(VMemFilterMode)mode
                           type:(VMemDataType)type
                     completion:(void (^)(NSUInteger count, NSString *msg))completion;
- (void)clearFastFuzzySnapshot;

#pragma mark - 快照

- (void)takeSnapshot;
- (void)clearSnapshot;
- (void)saveBaselineSnapshot;
- (void)clearBaselineSnapshot;
- (BOOL)hasBaselineSnapshot;

@end

// Backward compatibility
typedef VLMemEngine VMemEngine;

NS_ASSUME_NONNULL_END
