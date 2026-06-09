/**
 * VansonLoader L2.3 - VLFloatingButton 实现
 * 优化: 自动吸边、半透明、动画效果
 */

#import "VLFloatingButton.h"
#import "VLPanel.h"
#import "../Utils/VLIconManager.h"

UIWindow *GetSafeWindow(void);

static UIColor *VLFloatingAccentColor(void) {
    return [UIColor colorWithRed:0.18 green:0.96 blue:0.86 alpha:1.0];
}

static UIColor *VLFloatingSecondaryColor(void) {
    return [UIColor colorWithRed:0.56 green:0.38 blue:1.00 alpha:1.0];
}

static UIWindow *VLFloatingSafeWindow(VLFloatingButton *button) {
    UIWindow *window = button.window ?: GetSafeWindow();
    if (window) return window;
    return [UIApplication sharedApplication].windows.firstObject;
}

@interface VLFloatingButton ()
@property (nonatomic, assign) CGPoint lastPosition;
@property (nonatomic, assign) BOOL isDocked;
@property (nonatomic, assign) NSInteger idleCount;
@property (nonatomic, strong) NSTimer *idleTimer;
@property (nonatomic, assign) BOOL isDragging;
@end

@implementation VLFloatingButton

+ (instancetype)sharedButton {
    static VFloatingButton *btn;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        btn = [VFloatingButton buttonWithType:UIButtonTypeCustom];
        [btn setupButton];
    });
    return btn;
}

- (void)setupButton {
    UIWindow *window = VLFloatingSafeWindow(self);
    CGRect bounds = window ? window.bounds : [UIScreen mainScreen].bounds;
    CGFloat screenWidth = bounds.size.width;
    CGFloat screenHeight = bounds.size.height;

    // 获取安全区域底部高度
    CGFloat safeBottom = 34; // 默认值（有Home指示条的设备）
    if (@available(iOS 11.0, *)) {
        if (window) {
            safeBottom = MAX(window.safeAreaInsets.bottom, 20);
        }
    }

    // 初始位置: 右下角
    CGFloat initialY = screenHeight - safeBottom - 88;
    CGFloat initialX = screenWidth - 50 - 5;
    self.frame = CGRectMake(initialX, initialY, 50, 50);
    _lastPosition = self.center;
    _isDocked = NO;
    _idleCount = 0;
    _isDragging = NO;

    // 赛博朋克风格 - 半透明背景
    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.72];
    self.layer.cornerRadius = 25;
    self.layer.borderWidth = 2;
    self.layer.borderColor = [VLFloatingAccentColor() colorWithAlphaComponent:0.72].CGColor;
    self.clipsToBounds = YES;

    // 添加发光效果
    self.layer.shadowColor = VLFloatingAccentColor().CGColor;
    self.layer.shadowOffset = CGSizeZero;
    self.layer.shadowRadius = 12;
    self.layer.shadowOpacity = 0.55;
    self.layer.masksToBounds = NO;

    // 加载图标 (使用 VLIconManager, 支持自定义图标)
    NSString *selectedKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"Vanson_SelectedIcon"] ?: @"floating_button";
    UIImage *iconImg = IC(selectedKey);
    if (!iconImg) iconImg = IC(@"floating_button");
    if (iconImg) {
        [self setImage:iconImg forState:UIControlStateNormal];
        self.imageView.contentMode = UIViewContentModeScaleAspectFill;
        self.imageView.clipsToBounds = YES;
        self.imageView.layer.cornerRadius = 21;
        self.imageEdgeInsets = UIEdgeInsetsMake(4, 4, 4, 4);
        [self setTitle:nil forState:UIControlStateNormal];
    } else {
        [self setTitle:@"V" forState:UIControlStateNormal];
        [self setTitleColor:VLFloatingAccentColor() forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:22];
    }
    UIView *glow = [[UIView alloc] initWithFrame:self.bounds];
    glow.userInteractionEnabled = NO;
    glow.backgroundColor = [VLFloatingSecondaryColor() colorWithAlphaComponent:0.10];
    glow.layer.cornerRadius = 25;
    glow.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self insertSubview:glow atIndex:0];

    // 点击事件
    [self addTarget:self action:@selector(onTap) forControlEvents:UIControlEventTouchUpInside];

    // 拖动手势
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:pan];

    // 空闲计时器 (3秒后自动吸边半透明)
    _idleTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkIdle) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_idleTimer forMode:NSRunLoopCommonModes];

    // 初始动画
    self.alpha = 0;
    self.transform = CGAffineTransformMakeScale(0.5, 0.5);
    [UIView animateWithDuration:0.4 delay:0.2 usingSpringWithDamping:0.6 initialSpringVelocity:0.8 options:0 animations:^{
        self.alpha = 1.0;
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self updatePositionForCurrentWindowIfNeeded];
}

- (void)updatePositionForCurrentWindowIfNeeded {
    UIWindow *window = VLFloatingSafeWindow(self);
    if (!window || _isDragging) return;

    CGRect bounds = window.bounds;
    if (CGRectIsEmpty(bounds)) return;

    CGFloat safeTop = 70;
    CGFloat safeBottom = 34;
    if (@available(iOS 11.0, *)) {
        safeTop = MAX(window.safeAreaInsets.top + 15, 70);
        safeBottom = MAX(window.safeAreaInsets.bottom, 20);
    }

    CGFloat maxX = bounds.size.width - 25;
    CGFloat maxY = bounds.size.height - safeBottom - 25;
    CGFloat clampedX = MAX(25, MIN(self.center.x, maxX));
    CGFloat clampedY = MAX(safeTop + 25, MIN(self.center.y, maxY));

    if (CGPointEqualToPoint(self.center, CGPointZero) || !CGRectContainsPoint(bounds, self.center)) {
        clampedX = bounds.size.width - 30;
        clampedY = bounds.size.height - safeBottom - 63;
    }

    self.center = CGPointMake(clampedX, clampedY);
    _lastPosition = self.center;
}

- (void)onTap {
    if (_isDragging) return;

    // 点击动画
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];
    }];

    [VPanel toggle];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];

    if (gesture.state == UIGestureRecognizerStateBegan) {
        _isDragging = YES;
        _idleCount = 0;

        // 拖动开始: 恢复完全不透明
        [UIView animateWithDuration:0.15 animations:^{
            self.alpha = 1.0;
            self.transform = CGAffineTransformMakeScale(1.1, 1.1);
            self.layer.shadowOpacity = 0.8;
        }];
    }

    // 更新位置
    CGFloat newX = self.center.x + translation.x;
    CGFloat newY = self.center.y + translation.y;

    // 边界限制（避开灵动岛/刘海区域）
    UIWindow *window = VLFloatingSafeWindow(self);
    CGRect bounds = window ? window.bounds : [UIScreen mainScreen].bounds;
    CGFloat screenWidth = bounds.size.width;
    CGFloat screenHeight = bounds.size.height;
    CGFloat safeTop = 70; // 默认安全顶部距离
    if (@available(iOS 11.0, *)) {
        if (window) {
            safeTop = MAX(window.safeAreaInsets.top + 15, 70);
        }
    }
    newX = MAX(25, MIN(newX, screenWidth - 25));
    newY = MAX(safeTop + 25, MIN(newY, screenHeight - 60));

    self.center = CGPointMake(newX, newY);
    [gesture setTranslation:CGPointZero inView:self.superview];

    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        _isDragging = NO;
        _isDocked = NO;

        [UIView animateWithDuration:0.15 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];

        [self snapToEdge];
    }
}

- (void)snapToEdge {
    UIWindow *window = VLFloatingSafeWindow(self);
    CGRect bounds = window ? window.bounds : [UIScreen mainScreen].bounds;
    CGFloat screenWidth = bounds.size.width;
    CGFloat screenHeight = bounds.size.height;

    // 获取安全区域顶部高度（避开灵动岛/刘海）
    CGFloat safeTop = 70;
    if (@available(iOS 11.0, *)) {
        if (window) {
            safeTop = MAX(window.safeAreaInsets.top + 15, 70);
        }
    }

    // 吸附到最近的边缘
    CGFloat targetX;
    if (self.center.x < screenWidth / 2) {
        targetX = 30; // 左边
    } else {
        targetX = screenWidth - 30; // 右边
    }

    // Y 轴限制在安全区域（避开灵动岛）
    CGFloat targetY = MAX(safeTop + 25, MIN(self.center.y, screenHeight - 80));

    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:0 animations:^{
        self.center = CGPointMake(targetX, targetY);
        self.layer.shadowOpacity = 0.6;
    } completion:nil];

    _lastPosition = CGPointMake(targetX, targetY);
    _idleCount = 0;
}

- (void)checkIdle {
    if (_isDocked || _isDragging) return;

    _idleCount++;

    // 3秒后开始吸边并半透明
    if (_idleCount >= 3) {
        [self dockToEdge];
    }
}

- (void)dockToEdge {
    if (_isDocked) return;
    _isDocked = YES;

    UIWindow *window = VLFloatingSafeWindow(self);
    CGRect bounds = window ? window.bounds : [UIScreen mainScreen].bounds;
    CGFloat screenWidth = bounds.size.width;

    // 吸附到边缘 (露出约1/3)
    CGFloat targetX;
    if (self.center.x < screenWidth / 2) {
        targetX = 8; // 左边露出一点
    } else {
        targetX = screenWidth - 8; // 右边露出一点
    }

    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.3 options:0 animations:^{
        self.center = CGPointMake(targetX, self.center.y);
        self.alpha = 0.4; // 半透明
        self.layer.shadowOpacity = 0.3;
    } completion:nil];
}

- (void)wakeUp {
    if (!_isDocked) return;

    _isDocked = NO;
    _idleCount = 0;

    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:0 animations:^{
        self.center = _lastPosition;
        self.alpha = 1.0;
        self.layer.shadowOpacity = 0.6;
    } completion:nil];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];

    // 唤醒吸附状态的按钮
    if (_isDocked) {
        [self wakeUp];
    }
    _idleCount = 0;

    // 按下效果
    [UIView animateWithDuration:0.1 animations:^{
        self.layer.shadowOpacity = 1.0;
        self.layer.shadowRadius = 12;
    }];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];

    [UIView animateWithDuration:0.2 animations:^{
        self.layer.shadowOpacity = 0.6;
        self.layer.shadowRadius = 8;
    }];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];

    [UIView animateWithDuration:0.2 animations:^{
        self.layer.shadowOpacity = 0.6;
        self.layer.shadowRadius = 8;
    }];
}

+ (UIImage *)iconImage {
    static UIImage *img = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *b64 = @"PlaceHolder";
        NSData *data = [[NSData alloc] initWithBase64EncodedString:b64 options:0];
        if (data) img = [UIImage imageWithData:data];
    });
    return img;
}

@end
