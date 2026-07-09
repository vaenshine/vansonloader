/**
 * VansonLoader L2.3 - Script Manager
 * 脚本执行引擎实现 (H5GG 兼容)
 */

#import "VLScriptManager.h"
#import "VLMemEngine.h"
#import "../Utils/VLLocalization.h"
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>

extern "C" UIWindow *GetSafeWindow(void);
extern "C" void showToast(NSString *msg);

@interface VLScriptManager ()
@property (nonatomic, strong) JSContext *context;
@property (nonatomic, strong) NSMutableString *consoleLog;
@property (nonatomic, assign) uint64_t scriptBaseAddress;
@end

@implementation VLScriptManager

+ (instancetype)shared {
    static VLScriptManager *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [self new]; });
    return s;
}

static uint64_t VLManagerParseAddressArg(NSString *arg, uint64_t fallback) {
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

- (instancetype)init {
    if (self = [super init]) {
        _scriptBaseAddress = (uint64_t)_dyld_get_image_header(0);
    }
    return self;
}

#pragma mark - Type Conversion

- (VMemDataType)typeFromStr:(NSString *)str {
    if (!str) return VMemDataTypeI32;
    NSString *s = [str lowercaseString];
    
    if ([s isEqualToString:@"i8"]) return VMemDataTypeI8;
    if ([s isEqualToString:@"i16"]) return VMemDataTypeI16;
    if ([s isEqualToString:@"i32"]) return VMemDataTypeI32;
    if ([s isEqualToString:@"i64"]) return VMemDataTypeI64;
    if ([s isEqualToString:@"u8"]) return VMemDataTypeU8;
    if ([s isEqualToString:@"u16"]) return VMemDataTypeU16;
    if ([s isEqualToString:@"u32"]) return VMemDataTypeU32;
    if ([s isEqualToString:@"u64"]) return VMemDataTypeU64;
    if ([s isEqualToString:@"f32"] || [s isEqualToString:@"float"]) return VMemDataTypeF32;
    if ([s isEqualToString:@"f64"] || [s isEqualToString:@"double"]) return VMemDataTypeF64;
    if ([s isEqualToString:@"str"] || [s isEqualToString:@"string"]) return VMemDataTypeString;
    
    return VMemDataTypeI32;
}

#pragma mark - Script Execution

- (void)runScript:(NSString *)script
       completion:(void (^)(NSString *))completion {
    self.consoleLog = [NSMutableString string];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[VMemEngine shared] initialize];
        
        self.context = [[JSContext alloc] init];
        self.context[@"vm"] = self;
        
        __weak VScriptManager *weakSelf = self;
        
        self.context[@"print"] = ^(NSString *msg) {
            [weakSelf _log:[NSString stringWithFormat:@"%@", msg]];
        };
        
        // H5GG 兼容层
        NSString *polyfill = @"var h5gg = {"
            "  setFloatTolerance: function(v) { vm.setFloatTolerance(v); },"
            "  searchNumber: function(v, t, s, e) { return vm.search(v, t, s, e); },"
            "  searchNearby: function(v, t, r) { return vm.nearby(v, t, r); },"
            "  getValue: function(a, t) { return vm.getValue(a, t); },"
            "  setValue: function(a, v, t) { return vm.setValue(a, v, t); },"
            "  editAll: function(v, t) { return vm.editAll(v, t); },"
            "  getResultsCount: function() { return vm.getResultsCount(); },"
            "  getResults: function(c, s) { return vm.getResults(c, s); },"
            "  clearResults: function() { vm.clear(); },"
            "  getRangesList: function(n) { return vm.getRangesList(n); },"
            "  loadPlugin: function(c, p) { vm.log('Plugin not supported'); }"
            "};"
            "function fuckbase(addr, size) { vm.setBaseAddress(addr); }";
        [self.context evaluateScript:polyfill];
        
        self.context.exceptionHandler = ^(JSContext *context, JSValue *exception) {
            NSString *err = [exception toString];
            [weakSelf _log:[NSString stringWithFormat:@"[Error] %@", err]];
        };
        
        [self _log:@"--- Script Start ---"];
        [self.context evaluateScript:script];
        [self _log:@"--- Script End ---"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(self.consoleLog);
        });
    });
}

- (void)_log:(NSString *)msg {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm:ss";
    [self.consoleLog appendFormat:@"[%@] %@\n", [fmt stringFromDate:[NSDate date]], msg];
}

#pragma mark - VScriptExports

- (void)log:(NSString *)msg {
    [self _log:msg];
}

- (void)toast:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        showToast(msg);
    });
}

- (void)sleep:(double)seconds {
    [self _log:[NSString stringWithFormat:@"Sleep %.2fs", seconds]];
    usleep((useconds_t)(seconds * 1000000));
}

- (void)setFloatTolerance:(double)tolerance {
    [VMemEngine shared].floatTolerance = tolerance;
    [self _log:[NSString stringWithFormat:@"Float tolerance: %.6f", tolerance]];
}

- (void)setBaseAddress:(NSString *)addrStr {
    if (!addrStr) return;
    _scriptBaseAddress = strtoull([addrStr UTF8String], NULL, 16);
    [self _log:[NSString stringWithFormat:@"Base address: 0x%llX", _scriptBaseAddress]];
}

- (NSUInteger)search:(NSString *)val type:(NSString *)typeStr from:(NSString *)startArg to:(NSString *)endArg {
    if (!val || val.length == 0) return 0;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSUInteger resultCount = 0;
    uint64_t start = VLManagerParseAddressArg(startArg, 0);
    uint64_t end = VLManagerParseAddressArg(endArg, 0);
    
    VMemDataType type = [self typeFromStr:typeStr];
    BOOL useGroupMode =
        type != VMemDataTypeString &&
        ([val containsString:@";"] || [val containsString:@"::"] ||
         [val containsString:@" "]);

    [[VMemEngine shared] clearResults];
    [[VMemEngine shared] scanWithMode:useGroupMode ? VMemSearchModeGroup : VMemSearchModeExact
                                value:val
                                 type:type
                           rangeStart:start
                             rangeEnd:end
                           completion:^(NSUInteger count, NSString *msg) {
        resultCount = count;
        dispatch_semaphore_signal(sema);
    }];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    [self _log:[NSString stringWithFormat:@"Search '%@' found: %lu", val, (unsigned long)resultCount]];
    return resultCount;
}

- (NSUInteger)searchGroup:(NSString *)val type:(NSString *)typeStr from:(NSString *)startArg to:(NSString *)endArg {
    if (!val || val.length == 0) return 0;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSUInteger resultCount = 0;
    uint64_t start = VLManagerParseAddressArg(startArg, 0);
    uint64_t end = VLManagerParseAddressArg(endArg, 0);
    
    [[VMemEngine shared] clearResults];
    [[VMemEngine shared] scanWithMode:VMemSearchModeGroup
                                value:val
                                 type:[self typeFromStr:typeStr]
                           rangeStart:start
                             rangeEnd:end
                           completion:^(NSUInteger count, NSString *msg) {
        resultCount = count;
        dispatch_semaphore_signal(sema);
    }];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    [self _log:[NSString stringWithFormat:@"Group search found: %lu", (unsigned long)resultCount]];
    return resultCount;
}

- (NSUInteger)searchFuzzy:(NSString *)typeStr {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSUInteger resultCount = 0;
    
    [[VMemEngine shared] clearResults];
    [[VMemEngine shared] scanWithMode:VMemSearchModeFuzzy
                                value:@"0"
                                 type:[self typeFromStr:typeStr]
                           completion:^(NSUInteger count, NSString *msg) {
        resultCount = count;
        dispatch_semaphore_signal(sema);
    }];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    [self _log:[NSString stringWithFormat:@"Fuzzy search found: %lu", (unsigned long)resultCount]];
    return resultCount;
}

- (NSUInteger)searchSign:(NSString *)signature from:(NSString *)startArg to:(NSString *)endArg {
    if (!signature || signature.length == 0) return 0;
    
    uint64_t start = startArg ? strtoull([startArg UTF8String], NULL, 16) : 0;
    uint64_t end = endArg ? strtoull([endArg UTF8String], NULL, 16) : 0;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSUInteger count = 0;
    
    [[VMemEngine shared] scanSignature:signature
                            rangeStart:start
                              rangeEnd:end
                            completion:^(NSArray<VMemResultItem *> *results) {
        count = results.count;
        dispatch_semaphore_signal(sema);
    }];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    [self _log:[NSString stringWithFormat:@"Signature found: %lu", (unsigned long)count]];
    return count;
}

- (NSUInteger)nearby:(NSString *)val type:(NSString *)typeStr range:(double)range {
    if (!val || val.length == 0) return 0;
    if (range <= 0) range = 50;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSUInteger resultCount = 0;
    
    [[VMemEngine shared] scanNearbyWithValue:val
                                        type:[self typeFromStr:typeStr]
                                       range:(uint64_t)range
                                  completion:^(NSUInteger count, NSString *msg) {
        resultCount = count;
        dispatch_semaphore_signal(sema);
    }];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    [self _log:[NSString stringWithFormat:@"Nearby '%@' found: %lu", val, (unsigned long)resultCount]];
    return resultCount;
}

- (NSUInteger)searchBetween:(NSString *)minVal max:(NSString *)maxVal type:(NSString *)typeStr {
    if (!minVal || minVal.length == 0 || !maxVal || maxVal.length == 0) {
        [self _log:@"[Error] searchBetween requires min and max values"];
        return 0;
    }
    
    NSString *rangeStr = [NSString stringWithFormat:@"%@,%@", minVal, maxVal];
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSUInteger resultCount = 0;
    
    [[VMemEngine shared] clearResults];
    [[VMemEngine shared] scanWithMode:VMemSearchModeBetween
                                value:rangeStr
                                 type:[self typeFromStr:typeStr]
                           completion:^(NSUInteger count, NSString *msg) {
        resultCount = count;
        dispatch_semaphore_signal(sema);
    }];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    [self _log:[NSString stringWithFormat:@"Between search [%@~%@] found: %lu", minVal, maxVal, (unsigned long)resultCount]];
    return resultCount;
}

- (void)refine:(NSString *)val type:(NSString *)typeStr mode:(NSString *)modeStr {
    if (!val || val.length == 0) return;
    
    VMemFilterMode filterMode = VMemFilterModeUnchanged;
    if ([modeStr isEqualToString:@"gt"]) filterMode = VMemFilterModeGreater;
    else if ([modeStr isEqualToString:@"lt"]) filterMode = VMemFilterModeLess;
    else if ([modeStr isEqualToString:@"chg"]) filterMode = VMemFilterModeChanged;
    else if ([modeStr isEqualToString:@"inc"]) filterMode = VMemFilterModeIncreased;
    else if ([modeStr isEqualToString:@"dec"]) filterMode = VMemFilterModeDecreased;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSUInteger resultCount = 0;
    
    [[VMemEngine shared] nextScanWithValue:val
                                      type:[self typeFromStr:typeStr]
                                filterMode:filterMode
                                completion:^(NSUInteger count, NSString *msg) {
        resultCount = count;
        dispatch_semaphore_signal(sema);
    }];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    [self _log:[NSString stringWithFormat:@"Refine '%@' found: %lu", val, (unsigned long)resultCount]];
}

- (long)getResultsCount {
    return (long)[VMemEngine shared].resultCount;
}

- (long)count {
    return [self getResultsCount];
}

- (NSArray *)getResults:(int)count skip:(int)skip {
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

- (NSArray *)getRangesList:(NSString *)name {
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

- (void)clear {
    [[VMemEngine shared] clearResults];
    [self _log:@"Results cleared"];
}

- (NSString *)getValue:(NSString *)addrStr type:(NSString *)typeStr {
    uint64_t addr = strtoull([addrStr UTF8String], NULL, 16);
    return [[VMemEngine shared] readAddress:addr type:[self typeFromStr:typeStr]];
}

- (BOOL)setValue:(NSString *)addrStr val:(NSString *)val type:(NSString *)typeStr {
    if (!addrStr || addrStr.length == 0 || !val || val.length == 0) return NO;
    uint64_t addr = strtoull([addrStr UTF8String], NULL, 16);
    if (addr < 0x10000 || addr > 0x800000000000ULL) {
        [self _log:[NSString stringWithFormat:@"[Error] Invalid write address: %@", addrStr]];
        return NO;
    }
    return [[VMemEngine shared] writeAddress:addr value:val type:[self typeFromStr:typeStr]];
}

- (void)editAll:(NSString *)val type:(NSString *)typeStr filter:(NSString *)filter {
    VMemEngine *eng = [VMemEngine shared];
    VMemDataType type = [self typeFromStr:typeStr];
    NSUInteger total = eng.resultCount;
    
    if (total == 0) return;
    
    // 无过滤条件，批量修改
    if (!filter || filter.length == 0 || [filter isEqualToString:@"-1"]) {
        [eng batchModifyWithValue:val limit:0 type:type mode:0];
        [self _log:[NSString stringWithFormat:@"EditAll: %@", val]];
        return;
    }
    
    // 解析地址偏移 (//+0x28 或 //-8)
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
    
    // 有过滤条件，逐个处理
    int modifiedCount = 0;
    for (NSUInteger i = 0; i < MIN(total, (NSUInteger)1000); i++) {
        VMemResultItem *item = [eng getResultAtIndex:i type:type];
        if (!item) continue;
        
        NSUInteger idx = i + 1;
        
        // 无索引条件时，默认匹配所有结果（仅偏移）
        BOOL match = NO;
        if (!criteria || criteria.length == 0 || [criteria isEqualToString:@"-1"]) {
            match = YES;
        }
        // 范围匹配 1=10
        else if ([criteria containsString:@"="]) {
            NSArray *range = [criteria componentsSeparatedByString:@"="];
            if (range.count == 2) {
                int start = [range[0] intValue];
                int end = [range[1] intValue];
                match = (idx >= start && idx <= end);
            }
        }
        // 列表匹配 1,3,5
        else if ([criteria containsString:@","] || [criteria containsString:@"."]) {
            NSString *clean = [criteria stringByReplacingOccurrencesOfString:@"." withString:@","];
            NSArray *indices = [clean componentsSeparatedByString:@","];
            for (NSString *idxStr in indices) {
                if ([idxStr intValue] == idx) { match = YES; break; }
            }
        }
        // 单个索引
        else if (criteria.length > 0 && isdigit([criteria characterAtIndex:0])) {
            match = ([criteria intValue] == idx);
        }
        
        if (match) {
            uint64_t targetAddr = item.address + addrOffset;
            [eng writeAddress:targetAddr value:val type:type];
            modifiedCount++;
        }
    }
    
    [self _log:[NSString stringWithFormat:@"EditAll: %d modified", modifiedCount]];
}

- (void)editAll:(NSString *)val type:(NSString *)typeStr {
    [self editAll:val type:typeStr filter:nil];
}

- (void)writeAll:(NSString *)val type:(NSString *)typeStr {
    [self editAll:val type:typeStr];
}

- (void)write:(NSString *)val type:(NSString *)typeStr offset:(int)index {
    if (!val || index < 0) return;
    
    VMemDataType type = [self typeFromStr:typeStr];
    VMemResultItem *item = [[VMemEngine shared] getResultAtIndex:index type:type];
    if (item) {
        [[VMemEngine shared] writeAddress:item.address value:val type:type];
        [self _log:[NSString stringWithFormat:@"Write [%d] 0x%llX = %@", index, item.address, val]];
    }
}

- (void)lock:(NSString *)val type:(NSString *)typeStr index:(int)index {
    // VL 当前进程模式下，锁定通过定时器实现
    // 这里简化处理，直接写入值
    [self write:val type:typeStr offset:index];
    [self _log:[NSString stringWithFormat:@"Lock [%d] = %@", index, val]];
}

- (void)unlock:(int)index {
    [self _log:[NSString stringWithFormat:@"Unlock [%d]", index]];
}

- (void)lockAll:(NSString *)val type:(NSString *)typeStr filter:(NSString *)filter {
    [self editAll:val type:typeStr filter:filter];
    [self _log:@"LockAll done"];
}

- (void)unlockAll {
    [self _log:@"UnlockAll done"];
}

#pragma mark - Module Resolution Helpers

- (uint64_t)_resolveModuleBase:(NSString *)moduleName {
    // VansonLoader 是 in-process，直接用 dyld 查找
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
        
        // 读取当前地址的指针值
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

#pragma mark - [v2.6] Pointer Chain API

- (NSDictionary *)resolvePointer:(NSString *)moduleName
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
    
    VMemDataType type = [self typeFromStr:typeStr];
    NSString *val = [[VMemEngine shared] readAddress:finalAddr type:type];
    
    [self _log:[NSString stringWithFormat:@"[Pointer] 0x%llX -> %@", finalAddr, val]];
    return @{
        @"address": [NSString stringWithFormat:@"0x%llX", finalAddr],
        @"value": val ?: @"",
        @"success": @YES
    };
}

- (BOOL)writePointer:(NSString *)moduleName
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
    
    VMemDataType type = [self typeFromStr:typeStr];
    [[VMemEngine shared] writeAddress:finalAddr value:val type:type];
    [self _log:[NSString stringWithFormat:@"[Pointer] Write 0x%llX = %@", finalAddr, val]];
    return YES;
}

- (void)lockPointer:(NSString *)moduleName
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
    
    // 简化锁定：直接写入值 (VL 当前进程模式)
    VMemDataType type = [self typeFromStr:typeStr];
    [[VMemEngine shared] writeAddress:finalAddr value:val type:type];
    [self _log:[NSString stringWithFormat:@"[Pointer] Locked 0x%llX = %@ (%@)", finalAddr, val, note ?: @""]];
}

#pragma mark - [v2.6] RVA Patch API

- (BOOL)patchRVA:(NSString *)moduleName
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
        // Fallback: 通过 VMemEngine 写入
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

- (BOOL)restoreRVA:(NSString *)moduleName
            offset:(NSString *)offsetStr
       originalHex:(NSString *)originalHex {
    return [self patchRVA:moduleName offset:offsetStr patchHex:originalHex];
}

- (NSString *)readRVA:(NSString *)moduleName
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

@end
