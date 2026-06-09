/**
 * VansonLoader L2.3 - VLOverlayWindow 实现
 * 高层级覆盖窗口，确保悬浮按钮和面板不被其他窗口遮挡
 */

#import "VLOverlayWindow.h"

#pragma mark - VLOverlayViewController (不干扰屏幕方向)

@interface VLOverlayViewController : UIViewController
@end

@implementation VLOverlayViewController

static NSArray<UIWindow *> *VLSceneAwareWindows(void) {
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            if (scene.activationState != UISceneActivationStateForegroundActive &&
                scene.activationState != UISceneActivationStateForegroundInactive) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            [windows addObjectsFromArray:windowScene.windows];
        }
    }
    [windows addObjectsFromArray:[UIApplication sharedApplication].windows];
    return windows;
}

static UIWindow *VLAppWindowExcluding(UIWindow *excludedWindow) {
    UIWindow *fallbackWindow = nil;
    for (UIWindow *w in VLSceneAwareWindows()) {
        if (w == excludedWindow || !w.rootViewController) continue;
        if (!fallbackWindow) fallbackWindow = w;
        if (w.isKeyWindow) return w;
    }
    return fallbackWindow;
}

// 不干扰应用的方向设置，跟随应用本身的方向
- (BOOL)shouldAutorotate {
    UIViewController *appRootVC = VLAppWindowExcluding(self.view.window).rootViewController;
    return appRootVC ? [appRootVC shouldAutorotate] : YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // 跟随应用的方向设置
    UIViewController *appRootVC = VLAppWindowExcluding(self.view.window).rootViewController;
    return appRootVC ? [appRootVC supportedInterfaceOrientations] : UIInterfaceOrientationMaskAll;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    UIViewController *appRootVC = VLAppWindowExcluding(self.view.window).rootViewController;
    if (appRootVC && [appRootVC respondsToSelector:@selector(preferredInterfaceOrientationForPresentation)]) {
        return [appRootVC preferredInterfaceOrientationForPresentation];
    }
    return UIInterfaceOrientationPortrait;
}

@end

#pragma mark - VLOverlayWindow

@implementation VLOverlayWindow

static UIWindowScene *VLActiveWindowScene(void) {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *fallbackScene = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (!fallbackScene && scene.activationState == UISceneActivationStateForegroundInactive) {
                fallbackScene = windowScene;
            }
            if (!fallbackScene) fallbackScene = windowScene;
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                return windowScene;
            }
        }
        return fallbackScene;
    }
    return nil;
}

+ (instancetype)shared {
    static VLOverlayWindow *window = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = VLActiveWindowScene();
            if (scene) {
                window = [[VLOverlayWindow alloc] initWithWindowScene:scene];
            }
        }
        if (!window) {
            window = [[VLOverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }
        [window setup];
    });
    return window;
}

- (void)attachActiveSceneIfNeeded {
    CGRect targetFrame = [UIScreen mainScreen].bounds;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = VLActiveWindowScene();
        if (scene && self.windowScene != scene) {
            @try {
                self.windowScene = scene;
            } @catch (__unused NSException *exception) {
                scene = self.windowScene;
            }
        }
        if (scene) {
            targetFrame = scene.coordinateSpace.bounds;
        }
    }
    if (!CGRectIsEmpty(targetFrame)) {
        self.frame = targetFrame;
    }
    self.rootViewController.view.frame = self.bounds;
    self.rootViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.hidden = NO;
    self.alpha = 1.0;
}

- (void)setup {
    [self attachActiveSceneIfNeeded];

    // 设置超高层级，确保在所有窗口之上
    // UIWindowLevelAlert = 2000, 我们用 2100
    self.windowLevel = UIWindowLevelAlert + 100;

    // 透明背景，不阻挡下层
    self.backgroundColor = [UIColor clearColor];

    // 设置 rootViewController (iOS 13+ 必需)
    // 使用自定义 VC，不干扰应用的屏幕方向
    VLOverlayViewController *vc = [[VLOverlayViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    vc.view.userInteractionEnabled = YES;
    vc.view.frame = self.bounds;
    vc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.rootViewController = vc;
    [self attachActiveSceneIfNeeded];

    // 显示窗口
    self.hidden = NO;

    // 监听其他窗口变化，保持在最顶层
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidBecomeVisible:)
                                                 name:UIWindowDidBecomeVisibleNotification
                                               object:nil];
}

- (void)windowDidBecomeVisible:(NSNotification *)notification {
    // 当有新窗口出现时，确保我们的窗口在最顶层
    UIWindow *newWindow = notification.object;
    if (newWindow != self && newWindow.windowLevel >= self.windowLevel) {
        // 提升我们的层级
        self.windowLevel = newWindow.windowLevel + 1;
    }
    [self attachActiveSceneIfNeeded];
    self.hidden = NO;
}

+ (void)bringToFront {
    VLOverlayWindow *overlay = [self shared];
    [overlay attachActiveSceneIfNeeded];

    // 找到当前最高层级的窗口
    CGFloat maxLevel = UIWindowLevelAlert + 100;
    for (UIWindow *w in VLSceneAwareWindows()) {
        if (w != overlay && !w.hidden && w.alpha > 0.01 && w.windowLevel > maxLevel) {
            maxLevel = w.windowLevel;
        }
    }

    // 确保我们在最顶层
    if (overlay.windowLevel <= maxLevel) {
        overlay.windowLevel = maxLevel + 1;
    }

    overlay.hidden = NO;
}

// 只响应有子视图的区域，其他区域穿透
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];

    // 如果点击的是窗口本身或 rootViewController 的 view，则穿透
    if (hitView == self || hitView == self.rootViewController.view) {
        return nil;
    }

    return hitView;
}

@end
