/**
 * VansonLoader L2.7 - Tweak Entry
 * 统一面板架构入口
 */

#import "VansonLoader.h"
#import <objc/runtime.h>

// 全局数据定义
NSMutableArray<VLModItem *> *g_ptrItems = nil;
NSMutableArray<VLModItem *> *g_rvaItems = nil;
NSMutableArray<VLModItem *> *g_sigItems = nil;

// 声明外部变量（由 CoreGuard.m 维护）
extern int64_t _g_puzzle_piece;
static BOOL g_vlFloatingUIInstalled = NO;
static BOOL g_vlAboutChecked = NO;

static NSArray<UIWindow *> *VLAllApplicationWindows(void) {
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            if (scene.activationState != UISceneActivationStateForegroundActive &&
                scene.activationState != UISceneActivationStateForegroundInactive) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            [windows addObjectsFromArray:windowScene.windows];
        }
    }
    [windows addObjectsFromArray:UIApplication.sharedApplication.windows];
    return windows;
}

// 全局函数实现 - 使用 extern "C" 确保 C 链接
extern "C" UIWindow *GetSafeWindow(void) {
    // 返回我们的高层级覆盖窗口
    Class overlayClass = NSClassFromString(@"VLOverlayWindow");
    if (overlayClass) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        SEL sharedSel = NSSelectorFromString(@"shared");
        if ([overlayClass respondsToSelector:sharedSel]) {
            UIWindow *overlay = [overlayClass performSelector:sharedSel];
            if (overlay) {
                SEL attachSel = NSSelectorFromString(@"attachActiveSceneIfNeeded");
                if ([overlay respondsToSelector:attachSel]) {
                    [overlay performSelector:attachSel];
                }
                overlay.hidden = NO;
                return overlay;
            }
        }
#pragma clang diagnostic pop
    }

    for (UIWindow *w in VLAllApplicationWindows()) {
        if (w.isKeyWindow) return w;
    }
    for (UIWindow *w in VLAllApplicationWindows()) {
        if (!w.hidden && w.alpha > 0.01) return w;
    }
    return VLAllApplicationWindows().firstObject;
}

extern "C" void showToast(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = GetSafeWindow();
        if (!win) return;

        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 50)];
        l.center = win.center;
        l.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        l.textColor = [UIColor whiteColor];
        l.textAlignment = NSTextAlignmentCenter;
        l.text = msg;
        l.layer.cornerRadius = 10;
        l.clipsToBounds = YES;
        [win addSubview:l];

        [UIView animateWithDuration:0.3 delay:1.0 options:0 animations:^{
            l.alpha = 0;
        } completion:^(BOOL f) {
            [l removeFromSuperview];
        }];
    });
}

static BOOL VLInstallFloatingUIIfPossible(void) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            VLInstallFloatingUIIfPossible();
        });
        return NO;
    }

    Class btnClass = NSClassFromString(@"VLFloatingButton");
    if (!btnClass) return NO;

    Class overlayClass = NSClassFromString(@"VLOverlayWindow");
    UIWindow *w = nil;
    if (overlayClass) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        SEL sharedSel = NSSelectorFromString(@"shared");
        if ([overlayClass respondsToSelector:sharedSel]) {
            w = [overlayClass performSelector:sharedSel];
        }
        SEL frontSel = NSSelectorFromString(@"bringToFront");
        if ([overlayClass respondsToSelector:frontSel]) {
            [overlayClass performSelector:frontSel];
        }
#pragma clang diagnostic pop
    }
    if (!w) w = GetSafeWindow();
    if (!w) return NO;
    if (CGRectIsEmpty(w.bounds)) return NO;
    w.hidden = NO;
    w.alpha = 1.0;
    w.userInteractionEnabled = YES;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    SEL sel = NSSelectorFromString(@"sharedButton");
    if ([btnClass respondsToSelector:sel]) {
        UIView *btn = [btnClass performSelector:sel];
        if (btn) {
            if (btn.superview != w) {
                [btn removeFromSuperview];
                [w addSubview:btn];
            }
            btn.hidden = NO;
            btn.alpha = MAX(btn.alpha, 1.0);
            [w bringSubviewToFront:btn];
            SEL layoutSel = NSSelectorFromString(@"updatePositionForCurrentWindowIfNeeded");
            if ([btn respondsToSelector:layoutSel]) {
                [btn performSelector:layoutSel];
            }
        }
    }
#pragma clang diagnostic pop

    Class panelClass = NSClassFromString(@"VLPanel");
    if (panelClass) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        SEL initSel = NSSelectorFromString(@"initializeIfNeeded");
        if ([panelClass respondsToSelector:initSel]) {
            [panelClass performSelector:initSel];
        }
#pragma clang diagnostic pop
    }

    Class aboutClass = NSClassFromString(@"VLAbout");
    if (aboutClass && !g_vlAboutChecked) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        SEL checkSel = NSSelectorFromString(@"checkDisclaimerOnLaunch");
        if ([aboutClass respondsToSelector:checkSel]) {
            [aboutClass performSelector:checkSel];
            g_vlAboutChecked = YES;
        }
#pragma clang diagnostic pop
    }

    g_vlFloatingUIInstalled = YES;
    return YES;
}

static void VLScheduleFloatingUIInstall(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        VLInstallFloatingUIIfPossible();
    });
}

%ctor {
    // 加载配置
    [VLModParser loadConfig];

    dispatch_async(dispatch_get_main_queue(), ^{
        VLInstallFloatingUIIfPossible();
        __block NSInteger retry = 0;
        NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
            retry++;
            BOOL installed = VLInstallFloatingUIIfPossible();
            if ((installed && retry >= 8) || retry >= 120) {
                [timer invalidate];
            }
        }];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *note) {
            VLScheduleFloatingUIInstall();
        }];
        [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *note) {
            VLScheduleFloatingUIInstall();
        }];
        [center addObserverForName:UIWindowDidBecomeVisibleNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *note) {
            VLScheduleFloatingUIInstall();
        }];
        if (@available(iOS 13.0, *)) {
            [center addObserverForName:UISceneDidActivateNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *note) {
                VLScheduleFloatingUIInstall();
            }];
        }
    });
}
