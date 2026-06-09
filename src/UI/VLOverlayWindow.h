/**
 * VansonLoader L2.3 - VLOverlayWindow
 * 高层级覆盖窗口，确保悬浮按钮和面板不被其他窗口遮挡
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VLOverlayWindow : UIWindow

/// 获取共享的覆盖窗口
+ (instancetype)shared;

/// 确保窗口在最顶层
+ (void)bringToFront;

/// 挂载到当前活跃 scene
- (void)attachActiveSceneIfNeeded;

@end

NS_ASSUME_NONNULL_END
