/**
 * VansonLoader L2.3 - 脚本执行引擎实现
 * 修复: 线程安全、内存管理
 */

#import "VLScriptEngine.h"
#import "VLMemEngine.h"
#import "../Utils/VLLocalization.h"
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>

@interface VLScriptEngine ()
@property (nonatomic, strong) NSMutableString *consoleLog;
@property (nonatomic, assign) BOOL shouldStop;
@property (nonatomic, strong) NSMutableArray *lockedItems;  // 锁定项列表
@property (nonatomic, strong) NSTimer *lockTimer;           // 锁定定时器
@end

@implementation VLScriptEngine

+ (instancetype)shared {
    static VLScriptEngine *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[VLScriptEngine alloc] init];
        instance.lockedItems = [NSMutableArray array];
    });
    return instance;
}

static uint64_t VLParseAddressArg(NSString *arg, uint64_t fallback) {
    if (!arg || arg.length == 0) return fallback;
    NSString *trimmed = [arg stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0 ||
        [trimmed isEqualToString:@"undefined"] ||
        [trimmed isEqualToString:@"null"]) {
        return fallback;
    }
    return strtoull([trimmed UTF8String], NULL, 0);
}

#pragma mark - Script Execution

- (void)runScript:(NSString *)script
       completion:(void (^)(NSString *))completion {
    
    if (!script || script.length == 0) {
        if (completion) completion(@"[Error] Empty script");
        return;
    }
    
    self.consoleLog = [NSMutableString string];
    self.shouldStop = NO;
    
    // 确保内存引擎已初始化
    [[VMemEngine shared] initialize];
    
    // 复制脚本内容避免多线程问题
    NSString *scriptCopy = [script copy];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            @try {
                // 在后台线程创建 JSContext
                JSContext *context = [[JSContext alloc] init];
                if (!context) {
                    [self _log:@"[Error] Failed to create JSContext"];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (completion) completion(self.consoleLog);
                    });
                    return;
                }
                
                // 使用 __weak 避免循环引用
                __weak VScriptEngine *weakSelf = self;
                
                // 注册 vm 对象的方法
                context[@"vm"] = @{
                    @"log": ^(NSString *msg) {
                        [weakSelf _log:msg ?: @""];
                    },
                    @"toast": ^(NSString *msg) {
                        [weakSelf _toast:msg ?: @""];
                    },
                    @"sleep": ^(double seconds) {
                        [weakSelf _sleep:seconds];
                    },
                    @"search": ^(NSString *val, NSString *type, NSString *start, NSString *end) {
                        return [weakSelf _search:val type:type start:start end:end];
                    },
                    @"searchNumber": ^(NSString *val, NSString *type, NSString *start, NSString *end) {
                        return [weakSelf _search:val type:type start:start end:end];
                    },
                    @"searchGroup": ^(NSString *val, NSString *type, NSString *start, NSString *end) {
                        return [weakSelf _searchGroup:val type:type start:start end:end];
                    },
                    @"searchBetween": ^(NSString *minVal, NSString *maxVal, NSString *type) {
                        return [weakSelf _searchBetween:minVal max:maxVal type:type];
                    },
                    @"searchFuzzy": ^(NSString *type) {
                        return [weakSelf _searchFuzzy:type];
                    },
                    @"searchSign": ^(NSString *signature, NSString *start, NSString *end) {
                        return [weakSelf _searchSign:signature start:start end:end];
                    },
                    @"nearby": ^(NSString *val, NSString *type, double range) {
                        return [weakSelf _nearby:val type:type range:range];
                    },
                    @"refine": ^(NSString *val, NSString *type, NSString *mode) {
                        [weakSelf _refine:val type:type mode:mode];
                    },
                    @"getResultsCount": ^{
                        return [weakSelf _getResultsCount];
                    },
                    @"getResultCount": ^{
                        return [weakSelf _getResultsCount];
                    },
                    @"count": ^{
                        return [weakSelf _getResultsCount];
                    },
                    @"clear": ^{
                        [weakSelf _clear];
                    },
                    @"clearResults": ^{
                        [weakSelf _clear];
                    },
                    @"getValue": ^(NSString *addr, NSString *type) {
                        return [weakSelf _getValue:addr type:type];
                    },
                    @"setValue": ^(NSString *addr, NSString *val, NSString *type) {
                        return [weakSelf _setValue:addr val:val type:type];
                    },
                    @"readAddress": ^(NSString *addr, NSString *type) {
                        return [weakSelf _getValue:addr type:type];
                    },
                    @"writeAddress": ^(NSString *addr, NSString *val, NSString *type) {
                        return [weakSelf _setValue:addr val:val type:type];
                    },
                    @"write": ^(NSString *val, NSString *type, int index) {
                        [weakSelf _write:val type:type index:index];
                    },
                    @"editAll": ^(NSString *val, NSString *type, NSString *filter) {
                        [weakSelf _editAllWithFilter:val type:type filter:filter];
                    },
                    @"writeAll": ^(NSString *val, NSString *type) {
                        [weakSelf _editAll:val type:type];
                    },
                    @"lock": ^(NSString *val, NSString *type, int index) {
                        [weakSelf _lock:val type:type index:index];
                    },
                    @"unlock": ^(int index) {
                        [weakSelf _unlock:index];
                    },
                    @"lockAll": ^(NSString *val, NSString *type, NSString *filter) {
                        [weakSelf _lockAll:val type:type filter:filter];
                    },
                    @"unlockAll": ^{
                        [weakSelf _unlockAll];
                    },
                    @"getRangesList": ^(NSString *name) {
                        return [weakSelf _getRangesList:name];
                    },
                    @"getResults": ^(int count, int skip) {
                        return [weakSelf _getResults:count skip:skip];
                    },
                    @"setFloatTolerance": ^(double tol) {
                        [VMemEngine shared].floatTolerance = tol;
                        [weakSelf _log:[NSString stringWithFormat:@"Float tolerance: %.6f", tol]];
                    },
                    @"setBaseAddress": ^(NSString *addr) {
                        [weakSelf _log:[NSString stringWithFormat:@"Base address: %@", addr]];
                    },
                    // --- [v2.6] 指针链 ---
                    @"resolvePointer": ^(NSString *moduleName, NSString *baseOffset, NSArray *offsets, NSString *type) {
                        return [weakSelf _resolvePointer:moduleName baseOffset:baseOffset offsets:offsets type:type];
                    },
                    @"writePointer": ^(NSString *moduleName, NSString *baseOffset, NSArray *offsets, NSString *val, NSString *type) {
                        return [weakSelf _writePointer:moduleName baseOffset:baseOffset offsets:offsets val:val type:type];
                    },
                    @"lockPointer": ^(NSString *moduleName, NSString *baseOffset, NSArray *offsets, NSString *val, NSString *type, NSString *note) {
                        [weakSelf _lockPointer:moduleName baseOffset:baseOffset offsets:offsets val:val type:type note:note];
                    },
                    // --- [v2.6] RVA 补丁 ---
                    @"patchRVA": ^(NSString *moduleName, NSString *offset, NSString *patchHex) {
                        return [weakSelf _patchRVA:moduleName offset:offset patchHex:patchHex];
                    },
                    @"restoreRVA": ^(NSString *moduleName, NSString *offset, NSString *originalHex) {
                        return [weakSelf _restoreRVA:moduleName offset:offset originalHex:originalHex];
                    },
                    @"readRVA": ^(NSString *moduleName, NSString *offset, int length) {
                        return [weakSelf _readRVA:moduleName offset:offset length:length];
                    }
                };
                
                // print 函数
                context[@"print"] = ^(NSString *msg) {
                    [weakSelf _log:msg ?: @""];
                };
                
                // H5GG 兼容
                [context evaluateScript:@"var h5gg = vm; var H5GG = vm;"];
                
                // 异常处理
                context.exceptionHandler = ^(JSContext *ctx, JSValue *exception) {
                    NSString *err = [exception toString];
                    [weakSelf _log:[NSString stringWithFormat:@"[JS Error] %@", err]];
                };
                
                [self _log:@"--- Script Start ---"];
                
                // 执行脚本
                JSValue *result = [context evaluateScript:scriptCopy];
                if (result && ![result isUndefined] && ![result isNull]) {
                    [self _log:[NSString stringWithFormat:@"Result: %@", [result toString]]];
                }
                
                [self _log:@"--- Script End ---"];
                
            } @catch (NSException *exception) {
                [self _log:[NSString stringWithFormat:@"[Exception] %@: %@", exception.name, exception.reason]];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(self.consoleLog);
            });
        }
    });
}

- (void)stopExecution {
    self.shouldStop = YES;
}

#pragma mark - Logging

- (void)_log:(NSString *)msg {
    if (!msg) msg = @"";
    
    @synchronized (self.consoleLog) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"HH:mm:ss";
        NSString *ts = [fmt stringFromDate:[NSDate date]];
        [self.consoleLog appendFormat:@"[%@] %@\n", ts, msg];
    }
}

#pragma mark - Internal Methods (Thread Safe)

- (void)_toast:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *displayMsg = msg;
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:nil
                             message:displayMsg
                      preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *w in scene.windows) {
                        if (w.isKeyWindow) { window = w; break; }
                    }
                }
                if (window) break;
            }
        }
        if (!window) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            window = [[UIApplication sharedApplication] keyWindow];
#pragma clang diagnostic pop
        }
        if (window && window.rootViewController) {
            UIViewController *top = window.rootViewController;
            while (top.presentedViewController) top = top.presentedViewController;
            [top presentViewController:alert animated:YES completion:nil];
        }
    });
}

- (void)_sleep:(double)seconds {
    [self _log:[NSString stringWithFormat:@"Sleep %.2fs", seconds]];
    usleep((useconds_t)(seconds * 1000000));
}

- (VMemDataType)_typeFromStr:(NSString *)str {
    if (!str) return VMemDataTypeI32;
    NSString *upper = [str uppercaseString];
    if ([upper isEqualToString:@"I8"]) return VMemDataTypeI8;
    if ([upper isEqualToString:@"I16"]) return VMemDataTypeI16;
    if ([upper isEqualToString:@"I32"]) return VMemDataTypeI32;
    if ([upper isEqualToString:@"I64"]) return VMemDataTypeI64;
    if ([upper isEqualToString:@"U8"]) return VMemDataTypeU8;
    if ([upper isEqualToString:@"U16"]) return VMemDataTypeU16;
    if ([upper isEqualToString:@"U32"]) return VMemDataTypeU32;
    if ([upper isEqualToString:@"U64"]) return VMemDataTypeU64;
    if ([upper isEqualToString:@"F32"] || [upper isEqualToString:@"FLOAT"]) return VMemDataTypeF32;
    if ([upper isEqualToString:@"F64"] || [upper isEqualToString:@"DOUBLE"]) return VMemDataTypeF64;
    return VMemDataTypeI32;
}

- (NSUInteger)_search:(NSString *)val type:(NSString *)typeStr start:(NSString *)startArg end:(NSString *)endArg {
    if (!val || val.length == 0) {
        [self _log:@"[Error] Search value is empty"];
        return 0;
    }
    
    VMemEngine *engine = [VMemEngine shared];
    if (!engine.isReady) {
        [self _log:@"[Error] Memory engine not ready"];
        return 0;
    }
    
    VMemDataType type = [self _typeFromStr:typeStr];
    uint64_t start = VLParseAddressArg(startArg, 0);
    uint64_t end = VLParseAddressArg(endArg, 0);
    
    BOOL useGroupMode =
        type != VMemDataTypeString &&
        ([val containsString:@";"] || [val containsString:@"::"] ||
         [val containsString:@" "]);

    [engine clearResults];
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSUInteger count = 0;
    
    [engine scanWithMode:useGroupMode ? VMemSearchModeGroup : VMemSearchModeExact
                   value:val
                    type:type
              rangeStart:start
                rangeEnd:end
              completion:^(NSUInteger resultCount, NSString *msg) {
        count = resultCount;
        dispatch_semaphore_signal(sema);
    }];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    [self _log:[NSString stringWithFormat:@"Search '%@' found: %lu", val, (unsigned long)count]];
    return count;
}

- (NSUInteger)_searchGroup:(NSString *)val type:(NSString *)typeStr start:(NSString *)startArg end:(NSString *)endArg {
    if (!val || val.length == 0) {
        [self _log:@"[Error] Search value is empty"];
        return 0;
    }
    
    VMemEngine *engine = [VMemEngine shared];
    if (!engine.isReady) {
        [self _log:@"[Error] Memory engine not ready"];
        return 0;
    }
    
    VMemDataType type = [self _typeFromStr:typeStr];
    uint64_t start = VLParseAddressArg(startArg, 0);
    uint64_t end = VLParseAddressArg(endArg, 0);
    
    [engine clearResults];
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSUInteger count = 0;
    
    [engine scanWithMode:VMemSearchModeGroup
                   value:val
                    type:type
              rangeStart:start
                rangeEnd:end
              completion:^(NSUInteger resultCount, NSString *msg) {
        count = resultCount;
        dispatch_semaphore_signal(sema);
    }];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    [self _log:[NSString stringWithFormat:@"Group search '%@' found: %lu", val, (unsigned long)count]];
    return count;
}

- (NSUInteger)_searchBetween:(NSString *)minVal max:(NSString *)maxVal type:(NSString *)typeStr {
    if (!minVal || minVal.length == 0 || !maxVal || maxVal.length == 0) {
        [self _log:@"[Error] searchBetween requires min and max values"];
        return 0;
    }
    
    VMemEngine *engine = [VMemEngine shared];
    if (!engine.isReady) {
        [self _log:@"[Error] Memory engine not ready"];
        return 0;
    }
    
    VMemDataType type = [self _typeFromStr:typeStr];
    NSString *rangeStr = [NSString stringWithFormat:@"%@,%@", minVal, maxVal];
    
    [engine clearResults];
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSUInteger count = 0;
    
    [engine scanWithMode:VMemSearchModeBetween
                   value:rangeStr
                    type:type
              completion:^(NSUInteger resultCount, NSString *msg) {
        count = resultCount;
        dispatch_semaphore_signal(sema);
    }];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    [self _log:[NSString stringWithFormat:@"Between search [%@~%@] found: %lu", minVal, maxVal, (unsigned long)count]];
    return count;
}

- (NSUInteger)_searchFuzzy:(NSString *)typeStr {
    VMemEngine *engine = [VMemEngine shared];
    if (!engine.isReady) {
        [self _log:@"[Error] Memory engine not ready"];
        return 0;
    }
    
    [engine clearResults];
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSUInteger count = 0;
    
    [engine fastFuzzyInitWithCompletion:^(BOOL success, NSString *msg, NSUInteger addressCount) {
        count = addressCount;
        dispatch_semaphore_signal(sema);
    }];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    [self _log:[NSString stringWithFormat:@"Fuzzy search snapshot: %lu addresses", (unsigned long)count]];
    return count;
}

- (NSUInteger)_searchSign:(NSString *)signature start:(NSString *)startArg end:(NSString *)endArg {
    if (!signature || signature.length == 0) {
        [self _log:@"[Error] Signature is empty"];
        return 0;
    }
    
    VMemEngine *engine = [VMemEngine shared];
    if (!engine.isReady) {
        [self _log:@"[Error] Memory engine not ready"];
        return 0;
    }
    
    uint64_t start = startArg ? strtoull([startArg UTF8String], NULL, 16) : 0;
    uint64_t end = endArg ? strtoull([endArg UTF8String], NULL, 16) : 0;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSUInteger count = 0;
    
    [engine scanSignature:signature
               rangeStart:start
                 rangeEnd:end
               completion:^(NSArray<VLMemResultItem *> *results) {
        count = results.count;
        dispatch_semaphore_signal(sema);
    }];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    [self _log:[NSString stringWithFormat:@"Signature search found: %lu", (unsigned long)count]];
    return count;
}

- (NSUInteger)_nearby:(NSString *)val type:(NSString *)typeStr range:(double)range {
    if (!val || val.length == 0) {
        [self _log:@"[Error] Search value is empty"];
        return 0;
    }
    
    VMemEngine *engine = [VMemEngine shared];
    if (!engine.isReady) {
        [self _log:@"[Error] Memory engine not ready"];
        return 0;
    }
    
    if (range <= 0) range = 50;
    VMemDataType type = [self _typeFromStr:typeStr];
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSUInteger count = 0;
    
    [engine scanNearbyWithValue:val
                           type:type
                          range:(uint64_t)range
                     completion:^(NSUInteger resultCount, NSString *msg) {
        count = resultCount;
        dispatch_semaphore_signal(sema);
    }];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    [self _log:[NSString stringWithFormat:@"Nearby search '%@' found: %lu", val, (unsigned long)count]];
    return count;
}

- (void)_refine:(NSString *)val type:(NSString *)typeStr mode:(NSString *)modeStr {
    if (!val || val.length == 0) {
        [self _log:@"[Error] Refine value is empty"];
        return;
    }
    
    VMemEngine *engine = [VMemEngine shared];
    if (!engine.isReady) {
        [self _log:@"[Error] Memory engine not ready"];
        return;
    }
    
    VMemDataType type = [self _typeFromStr:typeStr];
    VMemFilterMode filterMode = (VMemFilterMode)100; // 默认精确匹配
    
    // 解析 mode 参数
    if ([modeStr isEqualToString:@"gt"]) {
        filterMode = VMemFilterModeGreater;
    } else if ([modeStr isEqualToString:@"lt"]) {
        filterMode = VMemFilterModeLess;
    } else if ([modeStr isEqualToString:@"chg"]) {
        filterMode = VMemFilterModeChanged;
    } else if ([modeStr isEqualToString:@"inc"]) {
        filterMode = VMemFilterModeIncreased;
    } else if ([modeStr isEqualToString:@"dec"]) {
        filterMode = VMemFilterModeDecreased;
    } else if ([modeStr isEqualToString:@"eq"]) {
        // 精确匹配或联合搜索
        if (type != VMemDataTypeString &&
            ([val containsString:@";"] || [val containsString:@"::"] ||
             [val containsString:@" "])) {
            // 联合搜索模式
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            __block NSUInteger count = 0;
            
            [engine scanWithMode:VMemSearchModeGroup
                           value:val
                            type:type
                      completion:^(NSUInteger resultCount, NSString *msg) {
                count = resultCount;
                dispatch_semaphore_signal(sema);
            }];
            
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [self _log:[NSString stringWithFormat:@"Refine '%@' found: %lu", val, (unsigned long)count]];
            return;
        }
        filterMode = (VMemFilterMode)100; // 精确匹配
    }
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSUInteger count = 0;
    
    [engine nextScanWithValue:val
                         type:type
                   filterMode:filterMode
                   completion:^(NSUInteger resultCount, NSString *msg) {
        count = resultCount;
        dispatch_semaphore_signal(sema);
    }];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    [self _log:[NSString stringWithFormat:@"Refine '%@' found: %lu", val, (unsigned long)count]];
}

- (void)_write:(NSString *)val type:(NSString *)typeStr index:(int)index {
    if (!val || val.length == 0) {
        [self _log:@"[Error] Write value is empty"];
        return;
    }
    if (index < 0) {
        [self _log:@"[Error] Index cannot be negative"];
        return;
    }
    
    VMemEngine *engine = [VMemEngine shared];
    VMemDataType type = [self _typeFromStr:typeStr];
    
    VMemResultItem *item = [engine getResultAtIndex:index type:type];
    if (item) {
        [engine writeAddress:item.address value:val type:type];
        [self _log:[NSString stringWithFormat:@"Write '%@' to [%d] 0x%llX", val, index, item.address]];
    } else {
        [self _log:[NSString stringWithFormat:@"[Error] Index %d out of bounds (total: %lu)", index, (unsigned long)engine.resultCount]];
    }
}

- (void)_editAllWithFilter:(NSString *)val type:(NSString *)typeStr filter:(NSString *)filter {
    VMemEngine *engine = [VMemEngine shared];
    VMemDataType type = [self _typeFromStr:typeStr];
    NSUInteger total = engine.resultCount;
    
    if (total == 0) {
        [self _log:@"[Error] No results to edit"];
        return;
    }
    
    // 无过滤条件，批量修改所有
    if (!filter || filter.length == 0 || [filter isEqualToString:@"-1"] ||
        [filter isEqualToString:@"undefined"] || [filter isEqualToString:@"null"]) {
        [engine batchModifyWithValue:val limit:0 type:type mode:0];
        [self _log:[NSString stringWithFormat:@"EditAll: modified %lu addresses to '%@'", (unsigned long)total, val]];
        return;
    }
    
    // 解析地址偏移 (//+4 或 //-8)
    long long addrOffset = 0;
    NSString *criteria = filter;
    if ([filter containsString:@"//"]) {
        NSArray *parts = [filter componentsSeparatedByString:@"//"];
        criteria = parts[0];
        if (parts.count > 1) {
            NSString *offStr = parts[1];
            if ([offStr hasPrefix:@"+"]) offStr = [offStr substringFromIndex:1];
            addrOffset = strtoll([offStr UTF8String], NULL, 16);
        }
    }
    
    // 带过滤条件的修改
    int modifiedCount = 0;
    NSUInteger maxEdit = MIN(total, (NSUInteger)1000);
    
    for (NSUInteger i = 0; i < maxEdit; i++) {
        NSUInteger currentIdx = i + 1; // 1-based index
        VMemResultItem *item = [engine getResultAtIndex:i type:type];
        if (!item) continue;
        
        uint64_t addr = item.address;
        NSString *currentValue = item.valueStr ?: @"";
        
        // 无索引/地址/数值条件时，默认匹配所有结果
        BOOL match = (!criteria || criteria.length == 0 || [criteria isEqualToString:@"-1"])
                     ? YES
                     : [self _matchFilter:criteria index:currentIdx address:addr value:currentValue];
        
        if (match) {
            uint64_t targetAddr = addr + addrOffset;
            [engine writeAddress:targetAddr value:val type:type];
            modifiedCount++;
        }
    }
    
    [self _log:[NSString stringWithFormat:@"EditAll: modified %d addresses to '%@'", modifiedCount, val]];
}

#pragma mark - Filter Expression Parser

// 解析过滤表达式，支持:
// - 索引列表: "1.3" 或 "1,3"
// - 索引范围: "1=10"
// - 地址尾数: "@ABC"
// - 数值包含: "||1024"
// - 组合: "1=10@ABC||1024"
- (BOOL)_matchFilter:(NSString *)criteria index:(NSUInteger)currentIdx address:(uint64_t)addr value:(NSString *)currentValue {
    if (!criteria || criteria.length == 0 || [criteria isEqualToString:@"-1"]) {
        return YES;
    }
    
    BOOL match = NO;
    BOOL hasRangeOrList = NO;
    BOOL hasAddrSuffix = NO;
    BOOL hasValueContains = NO;
    
    // 1. 解析索引范围/列表 (1=10 或 1.3 或 1,3)
    NSString *rangePart = criteria;
    if ([criteria containsString:@"@"]) {
        rangePart = [[criteria componentsSeparatedByString:@"@"] firstObject];
    }
    if ([rangePart containsString:@"||"]) {
        rangePart = [[rangePart componentsSeparatedByString:@"||"] firstObject];
    }
    
    if (rangePart.length > 0) {
        if ([rangePart containsString:@"="]) {
            hasRangeOrList = YES;
            NSArray *range = [rangePart componentsSeparatedByString:@"="];
            if (range.count == 2) {
                int start = [range[0] intValue];
                int end = [range[1] intValue];
                if (currentIdx >= start && currentIdx <= end) match = YES;
            }
        } else if ([rangePart containsString:@"."] || [rangePart containsString:@","]) {
            hasRangeOrList = YES;
            NSString *clean = [rangePart stringByReplacingOccurrencesOfString:@"." withString:@","];
            NSArray *indices = [clean componentsSeparatedByString:@","];
            for (NSString *idxStr in indices) {
                NSString *trimmed = [idxStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (trimmed.length > 0 && [trimmed intValue] == currentIdx) {
                    match = YES;
                    break;
                }
            }
        } else if (rangePart.length > 0 && isdigit([rangePart characterAtIndex:0])) {
            hasRangeOrList = YES;
            if ([rangePart intValue] == currentIdx) match = YES;
        }
    }
    
    // 2. 解析地址尾数匹配 (@ABC)
    if ([criteria containsString:@"@"]) {
        hasAddrSuffix = YES;
        NSString *suffix = [[criteria componentsSeparatedByString:@"@"] lastObject];
        if ([suffix containsString:@"||"]) {
            suffix = [[suffix componentsSeparatedByString:@"||"] firstObject];
        }
        suffix = [suffix lowercaseString];
        
        NSString *addrHex = [[NSString stringWithFormat:@"%llx", addr] lowercaseString];
        BOOL addrMatch = [addrHex hasSuffix:suffix];
        
        if (hasRangeOrList) {
            // 有范围限定时，取交集 (AND)
            match = match && addrMatch;
        } else {
            match = addrMatch;
        }
    }
    
    // 3. 解析数值包含 (||1024)
    if ([criteria containsString:@"||"]) {
        hasValueContains = YES;
        NSString *vSearch = [[criteria componentsSeparatedByString:@"||"] lastObject];
        BOOL valueMatch = [currentValue containsString:vSearch];
        
        if (hasRangeOrList || hasAddrSuffix) {
            // 有其他条件时，取交集 (AND)
            match = match && valueMatch;
        } else {
            match = valueMatch;
        }
    }
    
    // 如果没有任何条件，默认不匹配
    if (!hasRangeOrList && !hasAddrSuffix && !hasValueContains) {
        match = NO;
    }
    
    return match;
}

- (void)_lock:(NSString *)val type:(NSString *)typeStr index:(int)index {
    if (!val || val.length == 0) {
        [self _log:@"[Error] Lock value is empty"];
        return;
    }
    if (index < 0) {
        [self _log:@"[Error] Index cannot be negative"];
        return;
    }
    
    VMemEngine *engine = [VMemEngine shared];
    VMemDataType type = [self _typeFromStr:typeStr];
    
    if ((NSUInteger)index >= engine.resultCount) {
        [self _log:[NSString stringWithFormat:@"[Error] Index %d out of bounds (total: %lu)", index, (unsigned long)engine.resultCount]];
        return;
    }
    
    VMemResultItem *item = [engine getResultAtIndex:index type:type];
    if (!item) {
        [self _log:@"[Error] Failed to get result item"];
        return;
    }
    
    uint64_t addr = item.address;
    
    // 检查是否已锁定
    for (NSDictionary *lockItem in self.lockedItems) {
        if ([lockItem[@"addr"] unsignedLongLongValue] == addr) {
            [self _log:[NSString stringWithFormat:@"Address 0x%llX already locked", addr]];
            return;
        }
    }
    
    // 添加锁定项
    NSDictionary *lockItem = @{
        @"addr": @(addr),
        @"val": val,
        @"type": @(type),
        @"enabled": @(YES)
    };
    [self.lockedItems addObject:[lockItem mutableCopy]];
    
    // 启动锁定定时器
    [self _startLockTimer];
    
    [self _log:[NSString stringWithFormat:@"Lock [%d] 0x%llX = '%@'", index, addr, val]];
}

- (void)_unlock:(int)index {
    if (index < 0 || (NSUInteger)index >= self.lockedItems.count) {
        [self _log:[NSString stringWithFormat:@"[Error] Lock index %d out of bounds (total: %lu)", index, (unsigned long)self.lockedItems.count]];
        return;
    }
    
    NSDictionary *item = self.lockedItems[index];
    uint64_t addr = [item[@"addr"] unsignedLongLongValue];
    [self.lockedItems removeObjectAtIndex:index];
    
    // 如果没有锁定项了，停止定时器
    if (self.lockedItems.count == 0) {
        [self _stopLockTimer];
    }
    
    [self _log:[NSString stringWithFormat:@"Unlock [%d] 0x%llX", index, addr]];
}

- (void)_lockAll:(NSString *)val type:(NSString *)typeStr filter:(NSString *)filter {
    if (!val || val.length == 0) {
        [self _log:@"[Error] Lock value is empty"];
        return;
    }
    
    VMemEngine *engine = [VMemEngine shared];
    VMemDataType type = [self _typeFromStr:typeStr];
    NSUInteger total = engine.resultCount;
    
    if (total == 0) {
        [self _log:@"[Error] No results to lock"];
        return;
    }
    
    // 已锁定的地址集合
    NSMutableSet *existingAddrs = [NSMutableSet set];
    for (NSDictionary *item in self.lockedItems) {
        [existingAddrs addObject:item[@"addr"]];
    }
    
    NSString *criteria = filter ?: @"-1";
    if (criteria.length == 0) criteria = @"-1";
    
    NSUInteger addedCount = 0;
    NSUInteger maxLock = MIN(total, (NSUInteger)1000);
    
    for (NSUInteger i = 0; i < maxLock; i++) {
        VMemResultItem *item = [engine getResultAtIndex:i type:type];
        if (!item) continue;
        
        if ([existingAddrs containsObject:@(item.address)]) continue;
        
        NSUInteger currentIdx = i + 1; // 1-based index
        uint64_t addr = item.address;
        NSString *currentValue = item.valueStr ?: @"";
        
        BOOL match = [self _matchFilter:criteria index:currentIdx address:addr value:currentValue];
        
        if (match) {
            NSDictionary *lockItem = @{
                @"addr": @(addr),
                @"val": val,
                @"type": @(type),
                @"enabled": @(YES)
            };
            [self.lockedItems addObject:[lockItem mutableCopy]];
            [existingAddrs addObject:@(addr)];
            addedCount++;
        }
    }
    
    if (addedCount > 0) {
        [self _startLockTimer];
    }
    
    [self _log:[NSString stringWithFormat:@"LockAll: locked %lu addresses to '%@'", (unsigned long)addedCount, val]];
}

- (void)_unlockAll {
    NSUInteger count = self.lockedItems.count;
    [self.lockedItems removeAllObjects];
    [self _stopLockTimer];
    [self _log:[NSString stringWithFormat:@"UnlockAll: unlocked %lu addresses", (unsigned long)count]];
}

#pragma mark - Lock Timer

- (void)_startLockTimer {
    if (self.lockTimer) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.lockTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                          target:self
                                                        selector:@selector(_lockTimerTick)
                                                        userInfo:nil
                                                         repeats:YES];
    });
}

- (void)_stopLockTimer {
    if (self.lockTimer) {
        [self.lockTimer invalidate];
        self.lockTimer = nil;
    }
}

- (void)_lockTimerTick {
    if (self.lockedItems.count == 0) {
        [self _stopLockTimer];
        return;
    }
    
    VMemEngine *engine = [VMemEngine shared];
    if (!engine.isReady) return;
    
    for (NSDictionary *item in self.lockedItems) {
        if (![item[@"enabled"] boolValue]) continue;
        
        uint64_t addr = [item[@"addr"] unsignedLongLongValue];
        NSString *val = item[@"val"];
        VMemDataType type = (VMemDataType)[item[@"type"] unsignedIntegerValue];
        
        [engine writeAddress:addr value:val type:type];
    }
}

- (long)_getResultsCount {
    return (long)[VMemEngine shared].resultCount;
}

- (void)_clear {
    [[VMemEngine shared] clearResults];
    [self _log:@"Results cleared"];
}

- (NSString *)_getValue:(NSString *)addrStr type:(NSString *)typeStr {
    if (!addrStr) return @"0";
    uint64_t addr = strtoull([addrStr UTF8String], NULL, 16);
    NSString *result = [[VMemEngine shared] readAddress:addr type:[self _typeFromStr:typeStr]];
    return result ?: @"0";
}

- (BOOL)_setValue:(NSString *)addrStr val:(NSString *)val type:(NSString *)typeStr {
    if (!addrStr || addrStr.length == 0 || !val || val.length == 0) return NO;
    uint64_t addr = strtoull([addrStr UTF8String], NULL, 16);
    if (addr < 0x10000 || addr > 0x800000000000ULL) {
        [self _log:[NSString stringWithFormat:@"[Error] Invalid write address: %@", addrStr]];
        return NO;
    }
    return [[VMemEngine shared] writeAddress:addr value:val type:[self _typeFromStr:typeStr]];
}

- (void)_editAll:(NSString *)val type:(NSString *)typeStr {
    VMemEngine *engine = [VMemEngine shared];
    VMemDataType type = [self _typeFromStr:typeStr];
    NSUInteger total = engine.resultCount;
    
    if (total == 0) {
        [self _log:@"[Error] No results to edit"];
        return;
    }
    
    [engine batchModifyWithValue:val limit:0 type:type mode:0];
    
    [self _log:[NSString stringWithFormat:@"EditAll: modified %lu addresses", (unsigned long)total]];
}

- (NSArray *)_getRangesList:(NSString *)name {
    NSMutableArray *res = [NSMutableArray array];
    uint32_t count = _dyld_image_count();
    
    for (uint32_t i = 0; i < count; i++) {
        const char *imgName = _dyld_get_image_name(i);
        if (!imgName) continue;
        
        NSString *modName = [[NSString stringWithUTF8String:imgName] lastPathComponent];
        if (name && name.length > 0 && ![name isEqualToString:@"0"]) {
            if (![modName containsString:name]) continue;
        }
        
        uint64_t base = (uint64_t)_dyld_get_image_header(i);
        [res addObject:@{
            @"start": [NSString stringWithFormat:@"0x%llX", base],
            @"end": [NSString stringWithFormat:@"0x%llX", base + 0x1000000],
            @"name": modName,
            @"size": @"0x1000000"
        }];
    }
    return res;
}

- (NSArray *)_getResults:(int)count skip:(int)skip {
    NSMutableArray *arr = [NSMutableArray array];
    VMemEngine *eng = [VMemEngine shared];
    NSUInteger total = eng.resultCount;
    
    if (skip >= total) return @[];
    NSUInteger actualCount = MIN(count, total - skip);
    
    for (NSUInteger i = 0; i < actualCount; i++) {
        VMemResultItem *item = [eng getResultAtIndex:skip + i type:VMemDataTypeI32];
        if (item) {
            [arr addObject:@{
                @"address": [NSString stringWithFormat:@"0x%llX", item.address],
                @"value": item.valueStr ?: @"0",
                @"type": @(item.type)
            }];
        }
    }
    return arr;
}

#pragma mark - [v2.6] Module Resolution Helpers

- (uint64_t)_resolveModuleBase:(NSString *)moduleName {
    if (!moduleName || moduleName.length == 0 || [moduleName isEqualToString:@"virtual"]) {
        return (uint64_t)_dyld_get_image_header(0);
    }
    
    NSString *targetName = [moduleName lastPathComponent];
    uint32_t imageCount = _dyld_image_count();
    
    for (uint32_t i = 0; i < imageCount; i++) {
        const char *imgName = _dyld_get_image_name(i);
        if (!imgName) continue;
        
        NSString *modName = [[NSString stringWithUTF8String:imgName] lastPathComponent];
        if ([modName isEqualToString:targetName] ||
            [modName containsString:moduleName]) {
            return (uint64_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

- (uint64_t)_resolvePointerChain:(uint64_t)baseAddress offsets:(NSArray<NSNumber *> *)offsets {
    if (baseAddress == 0) return 0;
    
    VMemEngine *eng = [VMemEngine shared];
    uint64_t currentAddr = baseAddress;
    
    for (NSNumber *offsetNum in offsets) {
        int64_t offset = [offsetNum longLongValue];
        
        NSString *ptrStr = [eng readAddress:currentAddr type:VMemDataTypeI64];
        if (!ptrStr || [ptrStr isEqualToString:@"0"] || [ptrStr isEqualToString:@"? ?"]) {
            return 0;
        }
        
        uint64_t ptrValue = (uint64_t)strtoull([ptrStr UTF8String], NULL, 0);
        ptrValue = ptrValue & 0xFFFFFFFFFFFF; // 剥离 PAC
        currentAddr = (uint64_t)((int64_t)ptrValue + offset);
    }
    
    return currentAddr;
}

- (NSMutableArray<NSNumber *> *)_parseOffsets:(NSArray *)offsets {
    NSMutableArray<NSNumber *> *nsOffsets = [NSMutableArray array];
    for (id o in offsets) {
        if ([o isKindOfClass:[NSNumber class]]) {
            [nsOffsets addObject:o];
        } else {
            [nsOffsets addObject:@(strtoull([[o description] UTF8String], NULL, 0))];
        }
    }
    return nsOffsets;
}

- (NSData *)_dataFromHexString:(NSString *)hex {
    NSString *clean = [[hex stringByReplacingOccurrencesOfString:@" " withString:@""]
                        stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    if (clean.length % 2 != 0) return nil;
    
    NSMutableData *data = [NSMutableData dataWithCapacity:clean.length / 2];
    for (NSUInteger i = 0; i < clean.length; i += 2) {
        unsigned int byte;
        NSString *byteStr = [clean substringWithRange:NSMakeRange(i, 2)];
        if (![[NSScanner scannerWithString:byteStr] scanHexInt:&byte]) return nil;
        uint8_t b = (uint8_t)byte;
        [data appendBytes:&b length:1];
    }
    return data;
}

- (NSString *)_hexStringFromData:(NSData *)data {
    if (!data || data.length == 0) return @"";
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSMutableString *hex = [NSMutableString stringWithCapacity:data.length * 2];
    for (NSUInteger i = 0; i < data.length; i++) {
        [hex appendFormat:@"%02X", bytes[i]];
    }
    return hex;
}

#pragma mark - [v2.6] Pointer Chain Commands

- (NSDictionary *)_resolvePointer:(NSString *)moduleName
                       baseOffset:(NSString *)baseOffsetStr
                          offsets:(NSArray *)offsets
                             type:(NSString *)typeStr {
    uint64_t modBase = [self _resolveModuleBase:moduleName];
    if (modBase == 0) {
        [self _log:[NSString stringWithFormat:@"[Pointer] Error: Module '%@' not found", moduleName ?: @"virtual"]];
        return @{@"address": @"0x0", @"value": @"", @"success": @NO};
    }
    
    uint64_t baseOffset = strtoull([baseOffsetStr UTF8String], NULL, 16);
    NSArray<NSNumber *> *nsOffsets = [self _parseOffsets:offsets];
    
    uint64_t finalAddr = [self _resolvePointerChain:(modBase + baseOffset) offsets:nsOffsets];
    if (finalAddr == 0) {
        [self _log:@"[Pointer] Chain resolved to NULL"];
        return @{@"address": @"0x0", @"value": @"", @"success": @NO};
    }
    
    VMemDataType type = [self _typeFromStr:typeStr];
    NSString *val = [[VMemEngine shared] readAddress:finalAddr type:type];
    
    [self _log:[NSString stringWithFormat:@"[Pointer] 0x%llX -> %@", finalAddr, val]];
    return @{
        @"address": [NSString stringWithFormat:@"0x%llX", finalAddr],
        @"value": val ?: @"",
        @"success": @YES
    };
}

- (BOOL)_writePointer:(NSString *)moduleName
           baseOffset:(NSString *)baseOffsetStr
              offsets:(NSArray *)offsets
                  val:(NSString *)val
                 type:(NSString *)typeStr {
    uint64_t modBase = [self _resolveModuleBase:moduleName];
    if (modBase == 0) {
        [self _log:[NSString stringWithFormat:@"[Pointer] Error: Module '%@' not found", moduleName ?: @"virtual"]];
        return NO;
    }
    
    uint64_t baseOffset = strtoull([baseOffsetStr UTF8String], NULL, 16);
    NSArray<NSNumber *> *nsOffsets = [self _parseOffsets:offsets];
    
    uint64_t finalAddr = [self _resolvePointerChain:(modBase + baseOffset) offsets:nsOffsets];
    if (finalAddr == 0) {
        [self _log:@"[Pointer] Chain resolved to NULL, write aborted"];
        return NO;
    }
    
    VMemDataType type = [self _typeFromStr:typeStr];
    [[VMemEngine shared] writeAddress:finalAddr value:val type:type];
    [self _log:[NSString stringWithFormat:@"[Pointer] Write 0x%llX = %@", finalAddr, val]];
    return YES;
}

- (void)_lockPointer:(NSString *)moduleName
          baseOffset:(NSString *)baseOffsetStr
             offsets:(NSArray *)offsets
                 val:(NSString *)val
                type:(NSString *)typeStr
                note:(NSString *)note {
    uint64_t modBase = [self _resolveModuleBase:moduleName];
    if (modBase == 0) {
        [self _log:[NSString stringWithFormat:@"[Pointer] Error: Module '%@' not found", moduleName ?: @"virtual"]];
        return;
    }
    
    uint64_t baseOffset = strtoull([baseOffsetStr UTF8String], NULL, 16);
    NSArray<NSNumber *> *nsOffsets = [self _parseOffsets:offsets];
    
    uint64_t finalAddr = [self _resolvePointerChain:(modBase + baseOffset) offsets:nsOffsets];
    if (finalAddr == 0) {
        [self _log:@"[Pointer] Chain resolved to NULL, lock aborted"];
        return;
    }
    
    VMemDataType type = [self _typeFromStr:typeStr];
    
    // 检查是否已锁定
    for (NSDictionary *item in self.lockedItems) {
        if ([item[@"addr"] unsignedLongLongValue] == finalAddr) {
            [self _log:[NSString stringWithFormat:@"[Pointer] 0x%llX already locked", finalAddr]];
            return;
        }
    }
    
    NSDictionary *lockItem = @{
        @"addr": @(finalAddr),
        @"val": val,
        @"type": @(type),
        @"enabled": @(YES)
    };
    [self.lockedItems addObject:[lockItem mutableCopy]];
    [self _startLockTimer];
    
    [self _log:[NSString stringWithFormat:@"[Pointer] Locked 0x%llX = %@ (%@)", finalAddr, val, note ?: @""]];
}

#pragma mark - [v2.6] RVA Patch Commands

- (BOOL)_patchRVA:(NSString *)moduleName
           offset:(NSString *)offsetStr
         patchHex:(NSString *)patchHex {
    uint64_t modBase = [self _resolveModuleBase:moduleName];
    if (modBase == 0) {
        [self _log:[NSString stringWithFormat:@"[RVA] Error: Module '%@' not found", moduleName ?: @"virtual"]];
        return NO;
    }
    
    uint64_t offset = strtoull([offsetStr UTF8String], NULL, 16);
    uint64_t addr = modBase + offset;
    
    NSData *data = [self _dataFromHexString:patchHex];
    if (!data || data.length == 0) {
        [self _log:@"[RVA] Error: Invalid patch hex"];
        return NO;
    }
    
    // 修改内存保护为 RW
    mach_port_t task = mach_task_self();
    vm_protect(task, (vm_address_t)addr, data.length, FALSE,
               VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    
    // 写入补丁
    kern_return_t kr = vm_write(task, (vm_address_t)addr,
                                (vm_offset_t)data.bytes,
                                (mach_msg_type_number_t)data.length);
    
    // 恢复内存保护为 RX
    vm_protect(task, (vm_address_t)addr, data.length, FALSE,
               VM_PROT_READ | VM_PROT_EXECUTE);
    
    if (kr != KERN_SUCCESS) {
        BOOL fallback = [[VMemEngine shared] writeMemory:addr data:data];
        if (!fallback) {
            [self _log:[NSString stringWithFormat:@"[RVA] Write failed at 0x%llX (kern: %d)", addr, kr]];
            return NO;
        }
    }
    
    NSString *cleanHex = [[patchHex stringByReplacingOccurrencesOfString:@" " withString:@""]
                           stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    [self _log:[NSString stringWithFormat:@"[RVA] Patch 0x%llX (%@+0x%llX) = %@",
                addr, moduleName ?: @"virtual", offset, cleanHex]];
    return YES;
}

- (BOOL)_restoreRVA:(NSString *)moduleName
              offset:(NSString *)offsetStr
         originalHex:(NSString *)originalHex {
    return [self _patchRVA:moduleName offset:offsetStr patchHex:originalHex];
}

- (NSString *)_readRVA:(NSString *)moduleName
                offset:(NSString *)offsetStr
                length:(int)length {
    uint64_t modBase = [self _resolveModuleBase:moduleName];
    if (modBase == 0) {
        [self _log:[NSString stringWithFormat:@"[RVA] Error: Module '%@' not found", moduleName ?: @"virtual"]];
        return @"";
    }
    
    if (length <= 0 || length > 4096) {
        [self _log:@"[RVA] Error: Invalid length (1-4096)"];
        return @"";
    }
    
    uint64_t offset = strtoull([offsetStr UTF8String], NULL, 16);
    uint64_t addr = modBase + offset;
    
    NSData *data = [[VMemEngine shared] readMemory:addr length:length];
    if (!data) {
        [self _log:[NSString stringWithFormat:@"[RVA] Read failed at 0x%llX", addr]];
        return @"";
    }
    
    NSString *hex = [self _hexStringFromData:data];
    [self _log:[NSString stringWithFormat:@"[RVA] Read 0x%llX (%d bytes) = %@", addr, length, hex]];
    return hex;
}

#pragma mark - VScriptExports (Protocol Methods - Not Used Directly)

- (void)log:(NSString *)msg { [self _log:msg]; }
- (void)toast:(NSString *)msg { [self _toast:msg]; }
- (void)sleep:(double)seconds { [self _sleep:seconds]; }

- (NSUInteger)search:(NSString *)val type:(NSString *)type from:(NSString *)start to:(NSString *)end {
    return [self _search:val type:type start:start end:end];
}

- (NSUInteger)searchGroup:(NSString *)val type:(NSString *)type from:(NSString *)start to:(NSString *)end {
    return [self _searchGroup:val type:type start:start end:end];
}

- (NSUInteger)searchBetween:(NSString *)minVal max:(NSString *)maxVal type:(NSString *)type {
    return [self _searchBetween:minVal max:maxVal type:type];
}

- (void)refine:(NSString *)val type:(NSString *)type mode:(NSString *)mode {
    [self _log:@"refine not implemented"];
}

- (long)getResultsCount { return [self _getResultsCount]; }
- (long)count { return [self _getResultsCount]; }

- (NSArray *)getResults:(int)count skip:(int)skip {
    return @[];
}

- (void)clear { [self _clear]; }

- (NSString *)getValue:(NSString *)addrStr type:(NSString *)type {
    return [self _getValue:addrStr type:type];
}

- (BOOL)setValue:(NSString *)addrStr val:(NSString *)val type:(NSString *)type {
    return [self _setValue:addrStr val:val type:type];
}

- (void)editAll:(NSString *)val type:(NSString *)type filter:(NSString *)filter {
    [self _editAll:val type:type];
}

- (void)writeAll:(NSString *)val type:(NSString *)type {
    [self _editAll:val type:type];
}

// --- [v2.6] Pointer Chain Protocol Stubs ---

- (NSDictionary *)resolvePointer:(NSString *)moduleName
                      baseOffset:(NSString *)baseOffsetStr
                         offsets:(NSArray *)offsets
                            type:(NSString *)type {
    return [self _resolvePointer:moduleName baseOffset:baseOffsetStr offsets:offsets type:type];
}

- (BOOL)writePointer:(NSString *)moduleName
          baseOffset:(NSString *)baseOffsetStr
             offsets:(NSArray *)offsets
                 val:(NSString *)val
                type:(NSString *)type {
    return [self _writePointer:moduleName baseOffset:baseOffsetStr offsets:offsets val:val type:type];
}

- (void)lockPointer:(NSString *)moduleName
         baseOffset:(NSString *)baseOffsetStr
            offsets:(NSArray *)offsets
                val:(NSString *)val
               type:(NSString *)type
               note:(NSString *)note {
    [self _lockPointer:moduleName baseOffset:baseOffsetStr offsets:offsets val:val type:type note:note];
}

// --- [v2.6] RVA Patch Protocol Stubs ---

- (BOOL)patchRVA:(NSString *)moduleName
          offset:(NSString *)offsetStr
        patchHex:(NSString *)patchHex {
    return [self _patchRVA:moduleName offset:offsetStr patchHex:patchHex];
}

- (BOOL)restoreRVA:(NSString *)moduleName
            offset:(NSString *)offsetStr
       originalHex:(NSString *)originalHex {
    return [self _restoreRVA:moduleName offset:offsetStr originalHex:originalHex];
}

- (NSString *)readRVA:(NSString *)moduleName
               offset:(NSString *)offsetStr
               length:(int)length {
    return [self _readRVA:moduleName offset:offsetStr length:length];
}

@end
