/**
 * VansonLoader L2.3 - Debug Engine Implementation
 * ObjC Bridge -> C++ DebugCore
 */

#import "VLDebugEngine.h"
#import "../Core/VLCore.hpp"
#import "../Core/VLDebugCore.hpp"
#import "../Core/VLDisasm.hpp"
#import "../Utils/VLCrypto.h"
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <dlfcn.h>

using namespace vcore;

extern "C" void VLDebugSetLogPath(const char *path);

#pragma mark - VLStackFrame

@implementation VLStackFrame
@end

#pragma mark - VLWatchHit

@implementation VLWatchHit
@end

#pragma mark - VLDebugEngine

@implementation VLDebugEngine

+ (instancetype)shared {
    static VLDebugEngine *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[VLDebugEngine alloc] init];
    });
    return instance;
}

+ (BOOL)isAvailable {
    static BOOL available = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        available = DebugCore::inst().probeAvailability() ? YES : NO;
    });
    return available;
}

- (BOOL)attach {
    return DebugCore::inst().attach();
}

- (void)detach {
    DebugCore::inst().detach();
}

- (BOOL)isAttached {
    return DebugCore::inst().isAttached();
}

#pragma mark - Watchpoint Management

- (int)addWatchpoint:(uint64_t)address type:(VLWatchType)type size:(VLWatchSize)size {
    static dispatch_once_t logOnce;
    dispatch_once(&logOnce, ^{
        NSString *logPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/vldebug.log"];
        VLDebugSetLogPath(logPath.UTF8String);
    });
    return DebugCore::inst().addWatch(address, (WatchType)type, (WatchSize)size);
}

- (BOOL)removeWatchpoint:(uint32_t)index {
    return DebugCore::inst().removeWatch(index);
}

- (void)removeAllWatchpoints {
    DebugCore::inst().removeAll();
}

- (uint32_t)activeCount {
    return DebugCore::inst().activeCount();
}

- (uint32_t)maxSlots {
    return DebugCore::MAX_SLOTS;
}

- (BOOL)isSlotActive:(uint32_t)index {
    auto &slots = DebugCore::inst().getSlots();
    if (index >= slots.size()) return NO;
    return slots[index].active;
}

- (uint64_t)slotAddress:(uint32_t)index {
    auto &slots = DebugCore::inst().getSlots();
    if (index >= slots.size()) return 0;
    return slots[index].address;
}

#pragma mark - Hit Records

- (NSArray<VLWatchHit *> *)hitsForSlot:(uint32_t)index {
    auto &cppHits = DebugCore::inst().getHits(index);
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:cppHits.size()];
    
    for (auto &h : cppHits) {
        VLWatchHit *hit = [[VLWatchHit alloc] init];
        hit.slotIndex = h.wpIndex;
        hit.pc = h.pc;
        hit.address = h.address;
        hit.newValue = h.newValue;
        hit.imageName = [NSString stringWithUTF8String:h.imageName.c_str()];
        hit.offset = h.offset;
        hit.timestamp = h.timestamp;
        
        NSMutableArray<VLStackFrame *> *frames = [NSMutableArray array];
        for (auto &f : h.stackTrace) {
            VLStackFrame *frame = [[VLStackFrame alloc] init];
            frame.pc = f.pc;
            frame.imageName = [NSString stringWithUTF8String:f.imageName.c_str()];
            frame.imageBase = f.imageBase;
            frame.offset = f.offset;
            [frames addObject:frame];
        }
        hit.stackTrace = frames;
        [result addObject:hit];
    }
    
    return result;
}

- (void)clearHitsForSlot:(uint32_t)index {
    DebugCore::inst().clearHits(index);
}

- (void)clearAllHits {
    DebugCore::inst().clearAllHits();
}

- (void)setHitCallback:(VLWatchHitBlock)hitCallback {
    _hitCallback = hitCallback;
    
    if (hitCallback) {
        __weak __typeof__(self) weakSelf = self;
        DebugCore::inst().setHitCallback([weakSelf](const WatchHit &h) {
            __strong __typeof__(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || !strongSelf.hitCallback) return;
            
            VLWatchHit *hit = [[VLWatchHit alloc] init];
            hit.slotIndex = h.wpIndex;
            hit.pc = h.pc;
            hit.address = h.address;
            hit.newValue = h.newValue;
            hit.imageName = [NSString stringWithUTF8String:h.imageName.c_str()];
            hit.offset = h.offset;
            hit.timestamp = h.timestamp;
            hit.stackTrace = @[];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                strongSelf.hitCallback(hit);
            });
        });
    } else {
        DebugCore::inst().setHitCallback(nullptr);
    }
}

#pragma mark - Disassembly

- (NSArray<NSDictionary *> *)disassembleAt:(uint64_t)address
                               countBefore:(uint32_t)before
                                countAfter:(uint32_t)after
                                moduleName:(NSString *)moduleName {
    uint64_t base = MemEngine::inst().modBase(
        moduleName ? moduleName.UTF8String : nullptr);

    auto lines = vcore::disassemble(address, before, after, base);
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:lines.size()];

    for (auto &l : lines) {
        [result addObject:@{
            @"address": @(l.address),
            @"offset": @(l.offset),
            @"opcode": @(l.opcode),
            @"hex": [NSString stringWithUTF8String:l.hexStr.c_str()],
            @"mnemonic": [NSString stringWithUTF8String:l.mnemonic.c_str()],
            @"isPC": @(l.isPC)
        }];
    }
    return result;
}

- (NSArray<NSDictionary *> *)disassembleFunctionAt:(uint64_t)pc
                                        moduleName:(NSString *)moduleName {
    uint64_t base = MemEngine::inst().modBase(
        moduleName ? moduleName.UTF8String : nullptr);

    auto lines = vcore::disassembleFunction(pc, base);
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:lines.size()];

    for (auto &l : lines) {
        [result addObject:@{
            @"address": @(l.address),
            @"offset": @(l.offset),
            @"opcode": @(l.opcode),
            @"hex": [NSString stringWithUTF8String:l.hexStr.c_str()],
            @"mnemonic": [NSString stringWithUTF8String:l.mnemonic.c_str()],
            @"isPC": @(l.isPC)
        }];
    }
    return result;
}

#pragma mark - Runtime Patcher

- (BOOL)applyPatchAtOffset:(uint64_t)offset
                    hexCode:(NSString *)hex
                 moduleName:(NSString *)moduleName
              backupOriginal:(NSString **)outOriginal {
    if (!hex || hex.length == 0) return NO;
    
    uint64_t base = MemEngine::inst().modBase(
        moduleName ? moduleName.UTF8String : nullptr);
    if (base == 0) return NO;
    
    uint64_t addr = base + offset;
    NSData *patchData = [VCrypto dataFromHexString:hex];
    if (!patchData || patchData.length == 0) return NO;
    
    // 备份原始指令
    if (outOriginal) {
        void *origBuf = malloc(patchData.length);
        if (origBuf && MemEngine::inst().readMem(addr, origBuf, patchData.length)) {
            NSData *origData = [NSData dataWithBytesNoCopy:origBuf
                                                    length:patchData.length
                                              freeWhenDone:YES];
            *outOriginal = [VCrypto hexStringFromData:origData];
        } else {
            free(origBuf);
        }
    }
    
    // 写入补丁 (writeMem 内部处理 vm_protect + icache invalidate)
    return MemEngine::inst().writeMem(addr, patchData.bytes, patchData.length);
}

- (BOOL)restorePatchAtOffset:(uint64_t)offset
                  originalHex:(NSString *)originalHex
                   moduleName:(NSString *)moduleName {
    if (!originalHex || originalHex.length == 0) return NO;
    
    uint64_t base = MemEngine::inst().modBase(
        moduleName ? moduleName.UTF8String : nullptr);
    if (base == 0) return NO;
    
    uint64_t addr = base + offset;
    NSData *origData = [VCrypto dataFromHexString:originalHex];
    if (!origData || origData.length == 0) return NO;
    
    return MemEngine::inst().writeMem(addr, origData.bytes, origData.length);
}

@end
