/**
 * VansonLoader L2.3 - Memory Debug UI
 * 内存调试界面实现 (赛博朋克风格)
 * 参考 v2.5 优化：模糊搜索选项、筛选面板、附近搜索
 * 搜索结果已分离到独立窗口 VLMemResults
 */

#import "VLMemorySearch.h"
#import "VLPanelSizeHelper.h"
#import "VLMemoryBrowser.h"
#import "VLMemResults.h"
#import "VLDockBadge.h"
#import "VLPanel.h"
#import "../Utils/VLIconManager.h"
#import "../Engine/VLMemEngine.h"
#import "../Utils/VLLocalization.h"
#import <mach-o/dyld.h>
#import <AudioToolbox/AudioToolbox.h>

UIWindow *GetSafeWindow(void);
void showToast(NSString *msg);

// 触摸穿透模式（在 VLTools.m 中定义）
extern BOOL g_touchPassthroughMode;

// 前向声明：触摸穿透修复用的自定义容器视图
@class VLDockBadge;
@interface VLMemSearchContainerView : UIView
@property (nonatomic, weak) UIView *contentView;
@property (nonatomic, assign) BOOL isFocused;  // 焦点状态
@property (nonatomic, assign) BOOL isDocked;   // 收起状态
@property (nonatomic, assign) CGPoint dragStartPoint;  // 拖动起始点
@property (nonatomic, assign) CGPoint contentStartCenter;  // 内容起始中心
@property (nonatomic, strong) VLDockBadge *dockBadge;  // 可拖动的收起角标
- (void)setFocused:(BOOL)focused animated:(BOOL)animated;
- (void)dockToEdge;
- (void)undock;
@end

// 全局状态
VMemDataType g_currentType = VMemDataTypeI32;
static BOOL g_isSearching = NO;
static BOOL g_isFirstSearch = YES;
static BOOL g_isFuzzyLocked = NO;  // 模糊搜索锁定状态

// 收藏的地址集合 (用于快速查找)
// static NSMutableSet *g_favAddresses = nil;  // 已移除收藏功能

#pragma mark - VLMemorySearch

@implementation VLMemorySearch

+ (void)setupMemoryView:(UIScrollView *)container panel:(id)panel {
    CGFloat w = container.frame.size.width;
    CGFloat y = 8;
    CGFloat boxMargin = 12;
    CGFloat boxWidth = w - boxMargin * 2;
    
    // 内存搜索入口按钮
    UIView *memBox = [self createBox:VL(@"Mem_Title") y:y w:boxWidth h:75];
    memBox.frame = CGRectMake(boxMargin, y, boxWidth, 75);
    [container addSubview:memBox];
    
    UIButton *searchBtn = [self createBtn:VL(@"Mem_OpenSearch")
                                    frame:CGRectMake(10, 35, boxWidth - 20, 30)
                                    color:[UIColor cyanColor]];
    [searchBtn addTarget:self action:@selector(openMemorySearch)
        forControlEvents:UIControlEventTouchUpInside];
    [memBox addSubview:searchBtn];
    
    y += 90;
    
    // 快速状态显示
    UIView *statusBox = [self createBox:VL(@"Mem_Status") y:y w:boxWidth h:60];
    statusBox.frame = CGRectMake(boxMargin, y, boxWidth, 60);
    [container addSubview:statusBox];
    
    UILabel *countLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 30, boxWidth - 20, 20)];
    countLabel.tag = 1002;
    countLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.8];
    countLabel.font = [UIFont fontWithName:@"Menlo" size:12];
    countLabel.textAlignment = NSTextAlignmentCenter;
    [statusBox addSubview:countLabel];
    [self updateStatusLabel:countLabel];
    
    y += 75;
    container.contentSize = CGSizeMake(w, y + 20);
}

+ (void)updateStatusLabel:(UILabel *)label {
    NSUInteger count = [VMemEngine shared].resultCount;
    label.text = count > 0 ? [NSString stringWithFormat:@"%@: %lu", VL(@"Mem_Found"), (unsigned long)count] : VL(@"Mem_NoResults");
}

+ (void)openMemorySearch {
    UIWindow *w = GetSafeWindow();
    if (w) [VLMemorySearchVC showFromWindow:w];
}

+ (UIView *)createBox:(NSString *)title y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, h)];
    v.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.04];
    v.layer.cornerRadius = 10;
    v.layer.borderWidth = 1;
    v.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.2].CGColor;
    
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, w - 24, 22)];
    l.text = title;
    l.textColor = [UIColor cyanColor];
    l.font = [UIFont boldSystemFontOfSize:13];
    [v addSubview:l];
    return v;
}

+ (UIButton *)createBtn:(NSString *)title frame:(CGRect)frame color:(UIColor *)color {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = frame;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:color forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    b.layer.cornerRadius = 8;
    b.layer.borderColor = color.CGColor;
    b.layer.borderWidth = 1;
    b.backgroundColor = [color colorWithAlphaComponent:0.08];
    return b;
}

@end


#pragma mark - VLMemorySearchVC (单例模式，保持状态)

@interface VLMemorySearchVC () <UITextFieldDelegate>
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UITextField *valueField;
@property (nonatomic, strong) UISegmentedControl *typeSeg;      // 整数类型
@property (nonatomic, strong) UISegmentedControl *typeSeg2;     // 浮点/字符串类型
@property (nonatomic, strong) UISegmentedControl *modeSeg;
// 模糊搜索选项
@property (nonatomic, strong) UISegmentedControl *fuzzyRow1;
// 操作按钮容器
@property (nonatomic, strong) UIView *toolbarView;
// Console区域
@property (nonatomic, strong) UIView *consoleView;
@property (nonatomic, strong) UILabel *consoleLabel;
// 加载指示器
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
// 其他
@property (nonatomic, strong) UIButton *refreshBtnTop;  // 顶部刷新按钮（类型选择行旁边）
@property (nonatomic, strong) NSMutableDictionary *lockedItems;  // 地址 -> 锁定值
@property (nonatomic, assign) BOOL isNextScan;
@property (nonatomic, assign) BOOL isUISetup;
@end

static VLMemorySearchVC *g_memSearchVC = nil;

@implementation VLMemorySearchVC

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_memSearchVC = [[VLMemorySearchVC alloc] init];
    });
    return g_memSearchVC;
}

+ (void)showFromWindow:(UIWindow *)window {
    VLMemorySearchVC *vc = [self shared];
    
    if (vc.view.superview) {
        // 已经显示，只需要显示出来并重置焦点
        vc.view.hidden = NO;
        if ([vc.view isKindOfClass:[VLMemSearchContainerView class]]) {
            VLMemSearchContainerView *container = (VLMemSearchContainerView *)vc.view;
            [container setFocused:YES animated:NO];
            // 如果是收起状态，恢复面板
            if (container.isDocked) {
                [container undock];
            }
        }
        
        // 检查是否需要重建UI（语言变更后）
        if (!vc.isUISetup) {
            [vc rebuildUIForLanguageChange];
        }
        
        [UIView animateWithDuration:0.25 animations:^{
            vc.view.alpha = 1;
        }];
        return;
    }
    
    // 首次显示，添加到 window
    vc.view.frame = window.bounds;
    vc.view.alpha = 0;
    [window addSubview:vc.view];
    
    [UIView animateWithDuration:0.25 animations:^{
        vc.view.alpha = 1;
    }];
}

+ (void)showMinimized {
    UIWindow *w = GetSafeWindow();
    if (!w) return;
    
    VLMemorySearchVC *vc = [self shared];
    
    // 确保视图已初始化
    if (!vc.view.superview) {
        vc.view.frame = w.bounds;
        [w addSubview:vc.view];
    }
    
    vc.view.hidden = NO;
    vc.view.alpha = 1;
    
    // 直接设置为收起状态
    if ([vc.view isKindOfClass:[VLMemSearchContainerView class]]) {
        VLMemSearchContainerView *container = (VLMemSearchContainerView *)vc.view;
        container.contentView.hidden = YES;
        container.backgroundColor = [UIColor clearColor];
        container.isDocked = YES;
        // 直接显示悬浮图标
        [container.dockBadge showInQueueInView:container];
    }
}

+ (void)toggle {
    VLMemorySearchVC *vc = [self shared];
    if (vc.view.superview && !vc.view.hidden) {
        [vc hideWithAnimation];
    } else {
        UIWindow *w = GetSafeWindow();
        if (w) [self showFromWindow:w];
    }
}

+ (void)hide {
    VLMemorySearchVC *vc = [self shared];
    if (vc.view.superview && !vc.view.hidden) {
        [vc hideWithAnimation];
    }
}

+ (BOOL)isVisible {
    VLMemorySearchVC *vc = g_memSearchVC;
    return vc && vc.view.superview && !vc.view.hidden;
}

- (void)hideWithAnimation {
    [UIView animateWithDuration:0.2 animations:^{
        self.view.alpha = 0;
    } completion:^(BOOL finished) {
        self.view.hidden = YES;
        // 重置面板位置到屏幕中心
        if (self->_containerView) {
            CGFloat sw = self.view.bounds.size.width;
            CGFloat sh = self.view.bounds.size.height;
            self->_containerView.center = CGPointMake(sw / 2, sh / 2);
        }
        // 通知开关同步
        [[NSNotificationCenter defaultCenter] postNotificationName:@"VLWindowDidCloseNotification"
                                                            object:nil
                                                          userInfo:@{@"tag": @1001}];
    }];
}

- (void)close {
    [self hideWithAnimation];
    // 同时关闭搜索结果窗口
    [VLMemResults hide];
}

- (void)minimize {
    if ([self.view isKindOfClass:[VLMemSearchContainerView class]]) {
        [(VLMemSearchContainerView *)self.view dockToEdge];
    }
}

- (instancetype)init {
    if (self = [super init]) {
        self.lockedItems = [NSMutableDictionary dictionary];
        self.isNextScan = NO;
        self.isUISetup = NO;
        
        // 监听语言变更通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onLanguageChanged)
                                                     name:@"VansonLanguageChanged"
                                                   object:nil];
    }
    return self;
}

- (void)onLanguageChanged {
    // 语言变更时标记需要重建UI
    if (self.isUISetup) {
        self.isUISetup = NO;
        
        // 如果当前正在显示，立即重建
        if (self.view.superview && !self.view.hidden) {
            [self rebuildUIForLanguageChange];
        }
    }
}

- (void)rebuildUIForLanguageChange {
    // 清空并重建UI
    for (UIView *subview in _containerView.subviews) {
        [subview removeFromSuperview];
    }
    [_containerView removeFromSuperview];
    _containerView = nil;
    
    [self setupUI];
    self.isUISetup = YES;
    
    // 设置contentView引用
    if ([self.view isKindOfClass:[VLMemSearchContainerView class]]) {
        ((VLMemSearchContainerView *)self.view).contentView = _containerView;
    }
    
    [self updateUIForMode];
    [self loadResults];
}

- (void)dealloc {
    [self stopLockTimer];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// 使用自定义视图来处理触摸穿透问题
- (void)loadView {
    VLMemSearchContainerView *customView = [[VLMemSearchContainerView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view = customView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 初始背景色（焦点状态）
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    
    [[VMemEngine shared] initialize];
    
    if ([VMemEngine shared].resultCount > 0) {
        self.isNextScan = YES;
        g_isFirstSearch = NO;
    }
    
    [self setupUI];
    
    // 设置contentView引用，用于触摸穿透和拖动处理
    if ([self.view isKindOfClass:[VLMemSearchContainerView class]]) {
        VLMemSearchContainerView *container = (VLMemSearchContainerView *)self.view;
        container.contentView = _containerView;
        container.isFocused = YES;
    }
    
    self.isUISetup = YES;
    [self updateUIForMode];
    [self loadResults];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self relayoutContainer];
    } completion:nil];
}


- (void)setupUI {
    CGFloat sw = self.view.bounds.size.width;
    CGFloat sh = self.view.bounds.size.height;
    
    CGFloat margin = 8;
    
    // 固定尺寸：内存调试窗口不再显示结果列表
    // 标题26 + 模式28 + 类型26 + 类型2+搜索28 + 输入框36 + 工具栏34 + console40 + 底部边距8 = 226
    CGFloat totalW = MIN(sw * 0.94, 380);
    CGFloat totalH = 230;
    CGFloat ctrlW = totalW - margin * 2;
    
    // 主容器
    _containerView = [[UIView alloc] initWithFrame:CGRectMake((sw - totalW) / 2, (sh - totalH) / 2, totalW, totalH)];
    _containerView.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:0.98];
    _containerView.layer.cornerRadius = 14;
    _containerView.layer.borderWidth = 1.5;
    _containerView.layer.borderColor = [UIColor cyanColor].CGColor;
    _containerView.layer.shadowColor = [UIColor cyanColor].CGColor;
    _containerView.layer.shadowRadius = 15;
    _containerView.layer.shadowOpacity = 0.25;
    _containerView.clipsToBounds = YES;
    [self.view addSubview:_containerView];
    
    CGFloat y = 6;
    
    // ========== 标题栏 ==========
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, ctrlW, 22)];
    title.text = VL(@"Mem_Debug_Title");  // 改名：内存调试
    title.font = [UIFont fontWithName:@"Menlo-Bold" size:14];
    title.textColor = [UIColor cyanColor];
    title.textAlignment = NSTextAlignmentLeft;
    [_containerView addSubview:title];

    UIButton *timelineBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    timelineBtn.frame = CGRectMake(totalW - 70, y - 2, 28, 28);
    [timelineBtn setTitle:@"↺" forState:UIControlStateNormal];
    [timelineBtn setTitleColor:[[UIColor cyanColor] colorWithAlphaComponent:0.7] forState:UIControlStateNormal];
    timelineBtn.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    [timelineBtn addTarget:self action:@selector(showTimelineSheet) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:timelineBtn];
    
    // 最小化按钮 (子窗口只保留最小化，关闭由主窗口控制)
    UIButton *minBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    minBtn.frame = CGRectMake(totalW - 36, y - 4, 32, 32);
    [minBtn setTitle:@"−" forState:UIControlStateNormal];
    [minBtn setTitleColor:[[UIColor cyanColor] colorWithAlphaComponent:0.5] forState:UIControlStateNormal];
    [minBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateHighlighted];
    minBtn.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [minBtn addTarget:self action:@selector(minimize) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:minBtn];
    
    // 大中小缩放按钮
    VLPanelAddSizeButtons(_containerView, self.view.bounds, totalW, totalH);
    
    y += 26;
    
    // ========== 控制区域 ==========
    // 搜索模式 (先选模式)
    _modeSeg = [[UISegmentedControl alloc] initWithItems:@[VL(@"Mem_Tab_Exact"), VL(@"Mem_Tab_Fuzzy"), VL(@"Mem_Tab_Group")]];
    _modeSeg.frame = CGRectMake(margin, y, ctrlW, 24);
    _modeSeg.selectedSegmentIndex = 0;
    [self styleSegment:_modeSeg small:YES];
    [_modeSeg addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    [_containerView addSubview:_modeSeg];
    y += 28;
    
    // 数据类型选择 - 第一行：整数类型
    _typeSeg = [[UISegmentedControl alloc] initWithItems:@[@"I8", @"I16", @"I32", @"I64", @"U8", @"U16", @"U32", @"U64"]];
    _typeSeg.frame = CGRectMake(margin, y, ctrlW, 24);
    _typeSeg.selectedSegmentIndex = 2; // 默认 I32
    [self styleSegment:_typeSeg small:YES];
    [_typeSeg addTarget:self action:@selector(typeChanged:) forControlEvents:UIControlEventValueChanged];
    [_containerView addSubview:_typeSeg];
    y += 26;
    
    // 数据类型选择 - 第二行：浮点/字符串类型 + 刷新按钮
    CGFloat type2W = ctrlW * 0.48;
    CGFloat refreshBtnW = ctrlW - type2W - 6;
    
    _typeSeg2 = [[UISegmentedControl alloc] initWithItems:@[@"F32", @"F64", @"Str"]];
    _typeSeg2.frame = CGRectMake(margin, y, type2W, 24);
    _typeSeg2.selectedSegmentIndex = UISegmentedControlNoSegment;
    [self styleSegment:_typeSeg2 small:YES];
    [_typeSeg2 addTarget:self action:@selector(type2Changed:) forControlEvents:UIControlEventValueChanged];
    [_containerView addSubview:_typeSeg2];
    
    // 刷新按钮 (放在第二行类型选择右边)
    _refreshBtnTop = [self createBtn:VL(@"Refresh_Btn") frame:CGRectMake(margin + type2W + 6, y, refreshBtnW, 24) color:[UIColor cyanColor]];
    _refreshBtnTop.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [_refreshBtnTop addTarget:self action:@selector(doRefresh) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:_refreshBtnTop];
    y += 28;
    
    // 模糊搜索选项 (默认隐藏，单独一行)
    _fuzzyRow1 = [[UISegmentedControl alloc] initWithItems:@[VL(@"Fuz_Increased"), VL(@"Fuz_Decreased"), VL(@"Fuz_Unchanged"), VL(@"Fuz_Changed")]];
    _fuzzyRow1.frame = CGRectMake(margin, y, ctrlW, 28);
    _fuzzyRow1.hidden = YES;
    [self styleSegment:_fuzzyRow1 small:YES];
    [_containerView addSubview:_fuzzyRow1];
    // fuzzyRow1显示时会占用这行，y在updateUIForMode中动态调整
    
    // 输入框 (精确/联合模式)
    _valueField = [[UITextField alloc] initWithFrame:CGRectMake(margin, y, ctrlW, 32)];
    _valueField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:VL(@"Mem_InputValue") attributes:@{NSForegroundColorAttributeName: [[UIColor cyanColor] colorWithAlphaComponent:0.5]}];
    _valueField.textColor = [UIColor cyanColor];
    _valueField.font = [UIFont fontWithName:@"Menlo" size:12];
    _valueField.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.4].CGColor;
    _valueField.layer.borderWidth = 1;
    _valueField.layer.cornerRadius = 6;
    _valueField.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.05];
    _valueField.textAlignment = NSTextAlignmentCenter;
    _valueField.keyboardType = UIKeyboardTypeDecimalPad;
    _valueField.returnKeyType = UIReturnKeySearch;
    _valueField.delegate = self;
    [self addDoneButtonTo:_valueField];
    [_containerView addSubview:_valueField];
    y += 36;
    
    // ========== 工具栏容器 ==========
    _toolbarView = [[UIView alloc] initWithFrame:CGRectMake(margin, y, ctrlW, 30)];
    _toolbarView.backgroundColor = [UIColor clearColor];
    [_containerView addSubview:_toolbarView];
    y += 34;
    
    // ========== Console区域 ==========
    CGFloat consoleH = 36;
    _consoleView = [[UIView alloc] initWithFrame:CGRectMake(margin, y, ctrlW, consoleH)];
    _consoleView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    _consoleView.layer.cornerRadius = 6;
    _consoleView.layer.borderWidth = 1;
    _consoleView.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.2].CGColor;
    _consoleView.userInteractionEnabled = YES;
    // 点击 console 打开搜索结果
    UITapGestureRecognizer *consoleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onConsoleTap)];
    [_consoleView addGestureRecognizer:consoleTap];
    [_containerView addSubview:_consoleView];
    
    _consoleLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 4, ctrlW - 16, consoleH - 8)];
    _consoleLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.8];
    _consoleLabel.font = [UIFont fontWithName:@"Menlo" size:10];
    _consoleLabel.textAlignment = NSTextAlignmentCenter;
    _consoleLabel.numberOfLines = 2;
    _consoleLabel.text = VL(@"Mem_Ready");
    [_consoleView addSubview:_consoleLabel];
    y += consoleH + 4;
    
    // 启动锁定定时器
    [self startLockTimer];
    
    // 初始化工具栏
    [self rebuildToolbar];
}

- (void)onConsoleTap {
    // 有搜索结果时，点击打开搜索结果窗口
    if ([VMemEngine shared].resultCount > 0) {
        [VLMemResults show];
    }
}

#pragma mark - Console

- (void)logConsole:(NSString *)msg {
    _consoleLabel.text = msg;
}

#pragma mark - Toolbar (根据模式动态构建)

- (void)rebuildToolbar {
    // 清空现有按钮
    for (UIView *v in _toolbarView.subviews) {
        [v removeFromSuperview];
    }
    
    CGFloat w = _toolbarView.bounds.size.width;
    CGFloat h = _toolbarView.bounds.size.height;
    NSInteger mode = _modeSeg.selectedSegmentIndex;
    BOOL isFuzzy = (mode == 1);
    
    // 搜索按钮文字
    NSString *searchTitle;
    if (isFuzzy && !_isNextScan) {
        searchTitle = VL(@"Mem_Search");
    } else {
        searchTitle = _isNextScan ? VL(@"Mem_Next") : VL(@"Mem_Search");
    }
    
    // 0 = 精确, 1 = 模糊, 2 = 联合
    if (mode == 1) {
        // 模糊模式: 搜索 | 重置
        CGFloat btnW = (w - 6) / 2;
        UIButton *searchBtn = [self createToolBtn:searchTitle frame:CGRectMake(0, 0, btnW, h) action:@selector(doSearch)];
        UIButton *resetBtn = [self createToolBtn:VL(@"Mem_Reset") frame:CGRectMake(btnW + 6, 0, btnW, h) action:@selector(doReset)];
        resetBtn.layer.borderColor = [[UIColor orangeColor] colorWithAlphaComponent:0.8].CGColor;
        [resetBtn setTitleColor:[[UIColor orangeColor] colorWithAlphaComponent:0.8] forState:UIControlStateNormal];
        [_toolbarView addSubview:searchBtn];
        [_toolbarView addSubview:resetBtn];
    } else {
        // 精确/联合模式: 搜索 | 重置 | 批量
        CGFloat btnW = (w - 12) / 3;
        UIButton *searchBtn = [self createToolBtn:searchTitle frame:CGRectMake(0, 0, btnW, h) action:@selector(doSearch)];
        UIButton *resetBtn = [self createToolBtn:VL(@"Mem_Reset") frame:CGRectMake(btnW + 6, 0, btnW, h) action:@selector(doReset)];
        resetBtn.layer.borderColor = [[UIColor orangeColor] colorWithAlphaComponent:0.8].CGColor;
        [resetBtn setTitleColor:[[UIColor orangeColor] colorWithAlphaComponent:0.8] forState:UIControlStateNormal];
        UIButton *batchBtn = [self createToolBtn:VL(@"Batch_Btn") frame:CGRectMake(btnW * 2 + 12, 0, btnW, h) action:@selector(doBatch)];
        [_toolbarView addSubview:searchBtn];
        [_toolbarView addSubview:resetBtn];
        [_toolbarView addSubview:batchBtn];
    }
}

- (UIButton *)createToolBtn:(NSString *)title frame:(CGRect)frame action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = frame;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:10];
    b.layer.cornerRadius = 6;
    b.layer.borderColor = [UIColor cyanColor].CGColor;
    b.layer.borderWidth = 1;
    b.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.08];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}


#pragma mark - UI Helpers

- (void)styleSegment:(UISegmentedControl *)seg {
    [self styleSegment:seg small:NO];
}

- (void)styleSegment:(UISegmentedControl *)seg small:(BOOL)small {
    seg.selectedSegmentTintColor = [UIColor cyanColor];
    seg.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.1];
    UIFont *font = small ? [UIFont systemFontOfSize:10] : [UIFont systemFontOfSize:12];
    [seg setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor cyanColor], NSFontAttributeName: font} forState:UIControlStateNormal];
    [seg setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blackColor], NSFontAttributeName: font} forState:UIControlStateSelected];
}

- (UIButton *)createBtn:(NSString *)title frame:(CGRect)frame color:(UIColor *)color {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = frame;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:color forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    b.layer.cornerRadius = 8;
    b.layer.borderColor = color.CGColor;
    b.layer.borderWidth = 1;
    b.backgroundColor = [color colorWithAlphaComponent:0.08];
    return b;
}

- (void)addDoneButtonTo:(UITextField *)tf {
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 280, 44)];
    toolbar.barStyle = UIBarStyleBlack;
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *search = [[UIBarButtonItem alloc] initWithTitle:VL(@"Btn_Search") style:UIBarButtonItemStyleDone target:self action:@selector(onKeyboardSearch)];
    search.tintColor = [UIColor cyanColor];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:VL(@"Btn_Done") style:UIBarButtonItemStyleDone target:tf action:@selector(resignFirstResponder)];
    done.tintColor = [[UIColor cyanColor] colorWithAlphaComponent:0.6];
    toolbar.items = @[flex, search, done];
    tf.inputAccessoryView = toolbar;
}

- (void)onKeyboardSearch {
    [_valueField resignFirstResponder];
    [self doSearch];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _valueField) {
        [textField resignFirstResponder];
        // 触发搜索/二次搜索
        [self doSearch];
        return YES;
    }
    return YES;
}

#pragma mark - UI State

- (void)updateUIForMode {
    NSInteger mode = _modeSeg.selectedSegmentIndex;
    // 0 = 精确, 1 = 模糊, 2 = 联合
    BOOL isFuzzy = (mode == 1);
    BOOL isGroup = (mode == 2);
    
    CGFloat margin = 8;
    CGFloat ctrlW = _typeSeg.frame.size.width;
    CGFloat baseY = _typeSeg2.frame.origin.y + _typeSeg2.frame.size.height + 4;
    
    // ========== 类型限制逻辑 ==========
    BOOL isString = (g_currentType == VMemDataTypeString);
    
    // Str类型：模糊和联合搜索不可用
    [_modeSeg setEnabled:!isString forSegmentAtIndex:1]; // 模糊
    [_modeSeg setEnabled:!isString forSegmentAtIndex:2]; // 联合
    
    // 模糊/联合模式下：Str类型不可选
    BOOL strDisabled = (isFuzzy || isGroup);
    [_typeSeg2 setEnabled:!strDisabled forSegmentAtIndex:2]; // Str
    
    // ========== [修复] 移除模糊搜索锁定逻辑 ==========
    // 参考 VM 2.5.1: 所有模式共用结果，可以随时切换模式继续筛选
    // 不再锁定模式切换，用户可以自由在精确/模糊/联合之间切换
    NSUInteger resultCount = [VMemEngine shared].resultCount;
    BOOL hasResults = (resultCount > 0);
    
    // 有结果时解锁所有模式（除了类型限制）
    if (hasResults && g_isFuzzyLocked) {
        g_isFuzzyLocked = NO;
    }
    
    // 恢复所有模式的交互（除了类型限制）
    if (!isString) {
        [_modeSeg setEnabled:YES forSegmentAtIndex:0]; // 精确
        [_modeSeg setEnabled:YES forSegmentAtIndex:1]; // 模糊
        [_modeSeg setEnabled:YES forSegmentAtIndex:2]; // 联合
    }
    _typeSeg.userInteractionEnabled = YES;
    _typeSeg.alpha = 1.0;
    _typeSeg2.userInteractionEnabled = YES;
    _typeSeg2.alpha = 1.0;
    
    // ========== 模糊搜索UI布局 ==========
    if (isFuzzy) {
        if (_isNextScan) {
            // 模糊搜索后续筛选：显示fuzzyRow1，隐藏输入框
            _fuzzyRow1.hidden = NO;
            _fuzzyRow1.frame = CGRectMake(margin, baseY, ctrlW, 28);
            _valueField.hidden = YES;
            
            // 根据结果数量决定是否启用"无变化"选项（索引2）
            BOOL enableUnchanged = !g_isFirstSearch && (resultCount <= 20000000);
            [_fuzzyRow1 setEnabled:enableUnchanged forSegmentAtIndex:2];
        } else {
            // 模糊搜索首次：显示输入框作为提示，禁用输入
            _fuzzyRow1.hidden = YES;
            _valueField.hidden = NO;
            _valueField.frame = CGRectMake(margin, baseY, ctrlW, 32);
            _valueField.text = @"";
            _valueField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:VL(@"Fuz_First_Hint") attributes:@{NSForegroundColorAttributeName: [[UIColor cyanColor] colorWithAlphaComponent:0.5]}];
            _valueField.userInteractionEnabled = NO;
        }
    } else {
        // 精确/联合模式：显示输入框，隐藏模糊选项
        _fuzzyRow1.hidden = YES;
        _valueField.hidden = NO;
        _valueField.frame = CGRectMake(margin, baseY, ctrlW, 32);
        _valueField.userInteractionEnabled = YES;
        
        // 联合搜索模式提示
        if (isGroup) {
            _valueField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:VL(@"Mem_GroupHint") attributes:@{NSForegroundColorAttributeName: [[UIColor cyanColor] colorWithAlphaComponent:0.5]}];
            _valueField.keyboardType = UIKeyboardTypeDefault;
        } else if (isString) {
            _valueField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:VL(@"Mem_InputValue") attributes:@{NSForegroundColorAttributeName: [[UIColor cyanColor] colorWithAlphaComponent:0.5]}];
            _valueField.keyboardType = UIKeyboardTypeDefault;
        } else {
            _valueField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:VL(@"Mem_InputValue") attributes:@{NSForegroundColorAttributeName: [[UIColor cyanColor] colorWithAlphaComponent:0.5]}];
            _valueField.keyboardType = UIKeyboardTypeDecimalPad;
        }
    }
    
    // 重建工具栏（搜索按钮文字会在这里更新）
    [self rebuildToolbar];
}

- (void)typeChanged:(UISegmentedControl *)seg {
    // 第一行类型映射: I8=0, I16=1, I32=2, I64=3, U8=4, U16=5, U32=6, U64=7
    NSArray *typeMap = @[@(VMemDataTypeI8), @(VMemDataTypeI16), @(VMemDataTypeI32), @(VMemDataTypeI64),
                         @(VMemDataTypeU8), @(VMemDataTypeU16), @(VMemDataTypeU32), @(VMemDataTypeU64)];
    NSInteger idx = seg.selectedSegmentIndex;
    if (idx >= 0 && idx < typeMap.count) {
        g_currentType = (VMemDataType)[typeMap[idx] integerValue];
        // 取消第二行选中
        _typeSeg2.selectedSegmentIndex = UISegmentedControlNoSegment;
        // 更新UI状态（置灰逻辑）
        [self updateUIForMode];
    }
}

- (void)type2Changed:(UISegmentedControl *)seg {
    // 第二行类型映射: F32=0, F64=1, Str=2
    NSArray *typeMap = @[@(VMemDataTypeF32), @(VMemDataTypeF64), @(VMemDataTypeString)];
    NSInteger idx = seg.selectedSegmentIndex;
    if (idx >= 0 && idx < typeMap.count) {
        g_currentType = (VMemDataType)[typeMap[idx] integerValue];
        // 取消第一行选中
        _typeSeg.selectedSegmentIndex = UISegmentedControlNoSegment;
        
        // 字符串类型只能用精确搜索
        if (g_currentType == VMemDataTypeString && _modeSeg.selectedSegmentIndex != 0) {
            _modeSeg.selectedSegmentIndex = 0;
        }
        // 更新UI状态（置灰逻辑）
        [self updateUIForMode];
    }
}

- (void)modeChanged:(UISegmentedControl *)seg {
    [self updateUIForMode];
}

// bottomTabChanged 已移除，结果独立到 VLMemResults 窗口

- (void)relayoutContainer {
    // 保存当前状态
    NSInteger typeIdx = _typeSeg.selectedSegmentIndex;
    NSInteger type2Idx = _typeSeg2.selectedSegmentIndex;
    NSInteger modeIdx = _modeSeg.selectedSegmentIndex;
    NSInteger fuzzyIdx = _fuzzyRow1.selectedSegmentIndex;
    NSString *inputText = _valueField.text;
    NSString *consoleText = _consoleLabel.text;
    
    // 清空并重建UI
    for (UIView *subview in _containerView.subviews) {
        [subview removeFromSuperview];
    }
    [_containerView removeFromSuperview];
    _containerView = nil;
    
    [self setupUI];
    
    // 恢复状态
    _typeSeg.selectedSegmentIndex = typeIdx;
    _typeSeg2.selectedSegmentIndex = type2Idx;
    _modeSeg.selectedSegmentIndex = modeIdx;
    if (fuzzyIdx != UISegmentedControlNoSegment) {
        _fuzzyRow1.selectedSegmentIndex = fuzzyIdx;
    }
    _valueField.text = inputText;
    _consoleLabel.text = consoleText;
    
    // 设置contentView引用
    if ([self.view isKindOfClass:[VLMemSearchContainerView class]]) {
        ((VLMemSearchContainerView *)self.view).contentView = _containerView;
    }
    
    [self updateUIForMode];
    [self loadResults];
}

#pragma mark - Loading & Feedback

- (UIButton *)findSearchButtonInToolbar {
    // 搜索按钮现在在工具栏中（第一个按钮）
    for (UIView *v in _toolbarView.subviews) {
        if ([v isKindOfClass:[UIButton class]] && v.frame.origin.x < 10) {
            return (UIButton *)v;
        }
    }
    return nil;
}

- (void)showLoading {
    if (!_loadingIndicator) {
        _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        _loadingIndicator.color = [UIColor cyanColor];
        _loadingIndicator.hidesWhenStopped = YES;
    }
    
    // 找到工具栏中的搜索按钮
    UIButton *searchBtn = [self findSearchButtonInToolbar];
    if (searchBtn) {
        _loadingIndicator.center = CGPointMake(searchBtn.bounds.size.width / 2, searchBtn.bounds.size.height / 2);
        [searchBtn addSubview:_loadingIndicator];
        [_loadingIndicator startAnimating];
        
        // 隐藏按钮文字
        [searchBtn setTitle:@"" forState:UIControlStateNormal];
        searchBtn.userInteractionEnabled = NO;
    }
}

- (void)hideLoadingWithSuccess:(BOOL)success {
    [_loadingIndicator stopAnimating];
    [_loadingIndicator removeFromSuperview];
    
    // 恢复搜索按钮
    UIButton *searchBtn = [self findSearchButtonInToolbar];
    if (searchBtn) {
        searchBtn.userInteractionEnabled = YES;
    }
    
    // 恢复按钮文字
    [self updateUIForMode];
    
    // 震动反馈
    if (success) {
        // 成功震动 (轻微)
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback prepare];
        [feedback impactOccurred];
    } else {
        // 失败震动 (错误提示)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }
}

- (NSString *)timelineTypeName:(VMemDataType)type {
    NSArray *names = @[@"I8", @"I16", @"I32", @"I64", @"U8", @"U16", @"U32", @"U64", @"F32", @"F64", @"Str"];
    if (type < names.count) return names[type];
    return @"?";
}

- (NSString *)timelineModeTitle:(VMemSearchMode)mode {
    switch (mode) {
        case VMemSearchModeFuzzy: return VL(@"Timeline_Mode_Fuzzy");
        case VMemSearchModeGroup: return VL(@"Timeline_Mode_Group");
        case VMemSearchModeBetween: return VL(@"Timeline_Mode_Between");
        case VMemSearchModeExact:
        default: return VL(@"Timeline_Mode_Exact");
    }
}

- (NSString *)timelineFilterTitle:(VMemFilterMode)mode {
    switch (mode) {
        case VMemFilterModeIncreased: return VL(@"Fuz_Increased");
        case VMemFilterModeDecreased: return VL(@"Fuz_Decreased");
        case VMemFilterModeUnchanged: return VL(@"Fuz_Unchanged");
        case VMemFilterModeChanged: return VL(@"Fuz_Changed");
        case VMemFilterModeLess: return VL(@"Filter_Less");
        case VMemFilterModeGreater: return VL(@"Filter_Greater");
        case VMemFilterModeBetween: return VL(@"Filter_Between");
    }
}

- (void)captureTimelineTitle:(NSString *)title detail:(NSString *)detail {
    [[VMemEngine shared] captureTimelineWithTitle:title
                                           detail:detail
                                         dataType:g_currentType];
}

- (void)showTimelineSheet {
    NSArray<VLMemTimelineItem *> *items = [[VMemEngine shared] timelineItems];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"Timeline_Title")
                                                                message:items.count > 0 ? nil : VL(@"Timeline_Empty")
                                                         preferredStyle:UIAlertControllerStyleActionSheet];
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm:ss";

    for (NSUInteger i = 0; i < items.count; i++) {
        VLMemTimelineItem *item = items[i];
        NSString *time = [fmt stringFromDate:item.date ?: [NSDate date]];
        NSString *title = [NSString stringWithFormat:@"%@  %@ · %lu",
                                                     time,
                                                     item.title ?: @"",
                                                     (unsigned long)item.resultCount];
        NSString *detail = item.detail.length > 0 ? item.detail : @"";
        NSString *actionTitle = detail.length > 0 ? [NSString stringWithFormat:@"%@\n%@", title, detail] : title;
        [ac addAction:[UIAlertAction actionWithTitle:actionTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            if ([[VMemEngine shared] restoreTimelineAtIndex:i]) {
                g_currentType = item.dataType;
                self->_isNextScan = YES;
                [self loadResults];
                [self updateUIForMode];
                [VLMemResults show];
                [self logConsole:[NSString stringWithFormat:VL(@"Timeline_Restored_Fmt"), time, (unsigned long)item.resultCount]];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"VLMemResultsDidRestore" object:nil];
            } else {
                [self logConsole:VL(@"Timeline_Restore_Failed")];
            }
        }]];
    }

    if (items.count > 0) {
        [ac addAction:[UIAlertAction actionWithTitle:VL(@"Timeline_Clear") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            [[VMemEngine shared] clearTimeline];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];

    UIViewController *root = GetSafeWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:ac animated:YES completion:nil];
}

- (void)doSearch {
    if (g_isSearching) return;
    
    VMemSearchMode mode = (VMemSearchMode)_modeSeg.selectedSegmentIndex;
    
    if (mode == VMemSearchModeFuzzy && !_isNextScan) {
        [self doFuzzyFirstSearch];
        return;
    }
    
    if (mode == VMemSearchModeFuzzy && _isNextScan) {
        [self doFuzzyNextScan];
        return;
    }
    
    NSString *val = _valueField.text;
    if (val.length == 0) { [self logConsole:VL(@"Mem_InputRequired")]; return; }
    
    // 自动检测联合搜索模式 (值包含 ; 或 ::)
    if ([val containsString:@";"] || [val containsString:@"::"]) {
        mode = VMemSearchModeGroup;
    }
    
    // 自动检测范围搜索模式 (值包含 ~ 或 min-max 格式，如 90~100 或 90-100)
    // 排除负数 (如 -100) 和联合搜索
    BOOL isRangeSearch = NO;
    NSString *rangeVal = val;
    if (mode != VMemSearchModeGroup) {
        // 检测 ~ 分隔符
        if ([val containsString:@"~"]) {
            NSArray *parts = [val componentsSeparatedByString:@"~"];
            if (parts.count == 2 && [parts[0] length] > 0 && [parts[1] length] > 0) {
                rangeVal = [NSString stringWithFormat:@"%@,%@", parts[0], parts[1]];
                isRangeSearch = YES;
            }
        }
        // 检测 - 分隔符 (排除开头负号和科学计数法)
        if (!isRangeSearch && [val containsString:@"-"]) {
            NSRange dashRange = [val rangeOfString:@"-" options:0 range:NSMakeRange(1, val.length - 1)];
            if (dashRange.location != NSNotFound) {
                NSString *left = [val substringToIndex:dashRange.location];
                NSString *right = [val substringFromIndex:dashRange.location + 1];
                if (left.length > 0 && right.length > 0) {
                    // 确认两边都是数字
                    NSCharacterSet *validChars = [NSCharacterSet characterSetWithCharactersInString:@"0123456789.-"];
                    if ([[left stringByTrimmingCharactersInSet:validChars] length] == 0 &&
                        [[right stringByTrimmingCharactersInSet:validChars] length] == 0) {
                        rangeVal = [NSString stringWithFormat:@"%@,%@", left, right];
                        isRangeSearch = YES;
                    }
                }
            }
        }
        if (isRangeSearch) {
            mode = VMemSearchModeBetween;
            [self logConsole:[NSString stringWithFormat:@"ℹ️ %@", VL(@"Mem_BetweenHint")]];
        }
    }
    
    // Validate numeric input for non-String/non-Group types
    if (!_isNextScan && g_currentType != VMemDataTypeString && mode != VMemSearchModeGroup) {
        NSString *cleaned = [val stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (isRangeSearch) {
            NSArray *rangeParts = [rangeVal componentsSeparatedByString:@","];
            NSRegularExpression *numRx = [NSRegularExpression regularExpressionWithPattern:@"^-?\\d+\\.?\\d*$" options:0 error:nil];
            for (NSString *rp in rangeParts) {
                NSString *t = [rp stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (t.length == 0 || [numRx numberOfMatchesInString:t options:0 range:NSMakeRange(0, t.length)] == 0) {
                    [self logConsole:VL(@"Err_Range_Invalid")];
                    return;
                }
            }
        } else {
            NSRegularExpression *numRx = [NSRegularExpression regularExpressionWithPattern:@"^-?\\d+\\.?\\d*$" options:0 error:nil];
            if ([numRx numberOfMatchesInString:cleaned options:0 range:NSMakeRange(0, cleaned.length)] == 0) {
                [self logConsole:VL(@"Err_Not_Numeric")];
                return;
            }
        }
    }
    
    [_valueField resignFirstResponder];
    g_isSearching = YES;
    [self showLoading];
    [self logConsole:VL(@"Mem_Searching")];
    
    // [修复] 有结果时，精确/联合搜索都使用 nextScan 继续筛选
    // 参考 VM 2.5.1: 所有模式共用结果，可以随时切换模式继续筛选
    // searchMode 100 = 精确匹配目标值（不是比较变化）
    if (_isNextScan && [VMemEngine shared].resultCount > 0) {
        // 使用 VMemFilterModeExact (100) 进行精确值匹配筛选
        [[VMemEngine shared] nextScanWithValue:val type:g_currentType filterMode:(VMemFilterMode)100 completion:^(NSUInteger count, NSString *msg) {
            dispatch_async(dispatch_get_main_queue(), ^{
                g_isSearching = NO;
                [self hideLoadingWithSuccess:(count > 0)];
                [self logConsole:[NSString stringWithFormat:@"%@ %lu", VL(@"Mem_Found"), (unsigned long)count]];
                [self loadResults];
                // 有结果时自动显示搜索结果窗口
                if (count > 0) {
                    NSString *detail = [NSString stringWithFormat:@"%@ %@", [self timelineTypeName:g_currentType], val ?: @""];
                    [self captureTimelineTitle:[self timelineModeTitle:mode] detail:detail];
                    [VLMemResults show];
                }
            });
        }];
    } else {
        NSString *searchVal = isRangeSearch ? rangeVal : val;
        [[VMemEngine shared] scanWithMode:mode value:searchVal type:g_currentType completion:^(NSUInteger count, NSString *msg) {
            dispatch_async(dispatch_get_main_queue(), ^{
                g_isSearching = NO;
                [self hideLoadingWithSuccess:(count > 0)];
                self->_isNextScan = YES;
                g_isFirstSearch = NO;
                [self logConsole:[NSString stringWithFormat:@"%@ %lu", VL(@"Mem_Found"), (unsigned long)count]];
                [self updateUIForMode];
                [self loadResults];
                // 有结果时自动显示搜索结果窗口
                if (count > 0) {
                    NSString *detail = [NSString stringWithFormat:@"%@ %@", [self timelineTypeName:g_currentType], searchVal ?: @""];
                    [self captureTimelineTitle:[self timelineModeTitle:mode] detail:detail];
                    [VLMemResults show];
                }
            });
        }];
    }
}

- (void)doFuzzyFirstSearch {
    g_isSearching = YES;
    [self showLoading];
    [self logConsole:VL(@"Mem_Searching")];
    
    [[VMemEngine shared] fastFuzzyInitWithCompletion:^(BOOL success, NSString *msg, NSUInteger addressCount) {
        dispatch_async(dispatch_get_main_queue(), ^{
            g_isSearching = NO;
            [self hideLoadingWithSuccess:success];
            
            if (success) {
                self->_isNextScan = YES;
                g_isFirstSearch = YES;
                
                g_isFuzzyLocked = YES;
                
                NSString *countStr;
                if (addressCount >= 100000000) {
                    countStr = [NSString stringWithFormat:@"%.1f亿", addressCount / 100000000.0];
                } else if (addressCount >= 10000) {
                    countStr = [NSString stringWithFormat:@"%.1f万", addressCount / 10000.0];
                } else {
                    countStr = [NSString stringWithFormat:@"%lu", (unsigned long)addressCount];
                }
                [self logConsole:[NSString stringWithFormat:@"%@ %@ - %@", VL(@"Mem_Found"), countStr, VL(@"Fuz_Search_OK")]];
                
                [self updateUIForMode];
            } else {
                [self logConsole:msg ?: VL(@"Mem_Error")];
            }
        });
    }];
}

- (void)doFuzzyNextScan {
    VMemFilterMode filterMode = VMemFilterModeChanged;
    
    if (_fuzzyRow1.selectedSegmentIndex != UISegmentedControlNoSegment) {
        VMemFilterMode modes[] = {VMemFilterModeIncreased, VMemFilterModeDecreased, VMemFilterModeUnchanged, VMemFilterModeChanged};
        filterMode = modes[_fuzzyRow1.selectedSegmentIndex];
    } else {
        [self logConsole:VL(@"Fuz_Select_Mode")];
        return;
    }
    
    NSUInteger currentCount = [VMemEngine shared].resultCount;
    if (filterMode == VMemFilterModeUnchanged && currentCount > 20000000) {
        [self logConsole:VL(@"Fuz_Unchanged_TooMany")];
        return;
    }
    
    [_valueField resignFirstResponder];
    g_isSearching = YES;
    [self showLoading];
    [self logConsole:VL(@"Mem_Filtering")];
    
    // [修复] 始终使用 fastFuzzyFilter，它内部会处理：
    // 1. 有快照时：首次筛选，遍历快照对比
    // 2. 无快照但有结果时：累积筛选，基于存储的结果对比
    [[VMemEngine shared] fastFuzzyFilterWithMode:filterMode type:g_currentType completion:^(NSUInteger count, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            g_isSearching = NO;
            [self hideLoadingWithSuccess:(count > 0)];
            g_isFirstSearch = NO;
            [self logConsole:[NSString stringWithFormat:@"%@ %lu", VL(@"Mem_Found"), (unsigned long)count]];
            [self updateUIForMode];
            [self loadResults];
            // 有结果时自动显示搜索结果窗口
            if (count > 0) {
                NSString *detail = [self timelineTypeName:g_currentType];
                [self captureTimelineTitle:[self timelineFilterTitle:filterMode] detail:detail];
                [VLMemResults show];
            }
        });
    }];
}


- (void)doRefresh {
    [self loadResults];
    [self logConsole:VL(@"Refresh_Done")];
}

- (void)doBatch {
    NSUInteger count = [VMemEngine shared].resultCount;
    if (count == 0) {
        [self logConsole:VL(@"Mem_NoResults")];
        return;
    }
    
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"Batch_Btn")
                                                                message:nil
                                                         preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSString *modifyTitle = [NSString stringWithFormat:@"%@ (%lu)", VL(@"Batch_Modify"), (unsigned long)MIN(count, 100)];
    [ac addAction:[UIAlertAction actionWithTitle:modifyTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self showBatchModifyAlert];
    }]];
    
    NSString *copyTitle = [NSString stringWithFormat:@"%@ (%lu)", VL(@"Batch_Copy"), (unsigned long)MIN(count, 100)];
    [ac addAction:[UIAlertAction actionWithTitle:copyTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self copyAddresses];
    }]];
    
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    
    if (ac.popoverPresentationController) {
        ac.popoverPresentationController.sourceView = self.view;
        ac.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 1, 1);
    }
    
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)showBatchModifyAlert {
    NSUInteger count = MIN([VMemEngine shared].resultCount, 100);
    NSString *hint = [NSString stringWithFormat:VL(@"Batch_Modify_Hint"), (unsigned long)count];
    
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"Batch_Modify")
                                                                message:hint
                                                         preferredStyle:UIAlertControllerStyleAlert];
    
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = VL(@"Mem_NewValue");
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Mem_Write") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *val = ac.textFields.firstObject.text;
        if (val.length == 0) return;
        
        [[VMemEngine shared] batchModifyWithValue:val limit:100 type:g_currentType mode:0];
        
        NSString *msg = [NSString stringWithFormat:VL(@"Batch_Modified"), (unsigned long)count];
        [self logConsole:msg];
        [self loadResults];
    }]];
    
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)copyAddresses {
    NSUInteger count = MIN([VMemEngine shared].resultCount, 100);
    NSMutableString *addresses = [NSMutableString string];
    
    for (NSUInteger i = 0; i < count; i++) {
        VMemResultItem *item = [[VMemEngine shared] getResultAtIndex:i type:g_currentType];
        if (item) {
            [addresses appendFormat:@"0x%llX\n", item.address];
        }
    }
    
    if (addresses.length > 0) {
        [UIPasteboard generalPasteboard].string = addresses;
        NSString *msg = [NSString stringWithFormat:VL(@"Batch_Copied"), (unsigned long)count];
        [self logConsole:msg];
    }
}

- (void)doReset {
    [[VMemEngine shared] clearResults];
    [[VMemEngine shared] clearFastFuzzySnapshot];
    _isNextScan = NO;
    g_isFirstSearch = YES;
    _fuzzyRow1.selectedSegmentIndex = UISegmentedControlNoSegment;
    
    g_isFuzzyLocked = NO;
    [_modeSeg setEnabled:YES forSegmentAtIndex:0];
    [_modeSeg setEnabled:YES forSegmentAtIndex:2];
    [_fuzzyRow1 setEnabled:YES forSegmentAtIndex:2];
    
    _fuzzyRow1.hidden = YES;
    _valueField.hidden = NO;
    
    [self updateUIForMode];
    [self logConsole:VL(@"Mem_Ready")];
}

- (void)loadResults {
    NSUInteger total = [VMemEngine shared].resultCount;
    
    if (total > 0) {
        [self logConsole:[NSString stringWithFormat:@"%@ %lu", VL(@"Mem_Found"), (unsigned long)total]];
        
        // 通知搜索结果面板更新
        [VLMemResults notifyResultsUpdated];
    }
}

#pragma mark - Lock Timer

static NSTimer *g_lockTimer = nil;

- (void)startLockTimer {
    [self stopLockTimer];
    g_lockTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                   target:self
                                                 selector:@selector(lockTimerTick)
                                                 userInfo:nil
                                                  repeats:YES];
}

- (void)stopLockTimer {
    if (g_lockTimer) {
        [g_lockTimer invalidate];
        g_lockTimer = nil;
    }
}

- (void)lockTimerTick {
    if (_lockedItems.count == 0) return;
    
    VMemEngine *engine = [VMemEngine shared];
    if (!engine.isReady) return;
    
    // 持续写入锁定的值
    for (NSNumber *addrNum in _lockedItems) {
        NSDictionary *info = _lockedItems[addrNum];
        NSString *lockVal = info[@"value"];
        VMemDataType lockType = (VMemDataType)[info[@"type"] unsignedIntegerValue];
        [engine writeAddress:[addrNum unsignedLongLongValue] value:lockVal type:lockType];
    }
}

#pragma mark - Touch Event Handling (触摸穿透修复)

// 处理点击containerView外部区域的事件 - 关闭键盘
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self.view];
    CGPoint containerPoint = [self.view convertPoint:point toView:_containerView];
    
    // 如果点击在containerView外部，关闭键盘
    if (![_containerView pointInside:containerPoint withEvent:event]) {
        [self.view endEditing:YES];
    }
    
    [super touchesBegan:touches withEvent:event];
}

@end


#pragma mark - VLMemSearchContainerView (触摸穿透修复)

@implementation VLMemSearchContainerView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _isFocused = YES;
        _isDocked = NO;
        [self setupDockBadge];
    }
    return self;
}

- (void)setupDockBadge {
    // 使用可拖动的 VLDockBadge 组件
    _dockBadge = [[VLDockBadge alloc] initWithImage:IC(@"memory_debug") fallbackIcon:@"🔍"];
    _dockBadge.hidden = YES;
    __weak typeof(self) weakSelf = self;
    _dockBadge.onTap = ^{
        [weakSelf undock];
    };
    [self addSubview:_dockBadge];
}

- (void)dockToEdge {
    if (_isDocked) return;
    _isDocked = YES;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.contentView.alpha = 0;
        self.contentView.transform = CGAffineTransformMakeScale(0.5, 0.5);
        self.backgroundColor = [UIColor clearColor];
    } completion:^(BOOL finished) {
        self.contentView.hidden = YES;
        // 使用自动排队显示
        [self->_dockBadge showInQueueInView:self];
    }];
}

- (void)undock {
    if (!_isDocked) return;
    _isDocked = NO;
    
    self.contentView.hidden = NO;
    [_dockBadge hideAnimated:YES];
    
    [UIView animateWithDuration:0.3 animations:^{
        self.contentView.alpha = 1;
        self.contentView.transform = CGAffineTransformIdentity;
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    } completion:^(BOOL finished) {
        self->_isFocused = YES;
    }];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.01) return nil;
    
    // 收起状态：只响应角标（角标自己处理拖动）
    if (_isDocked) {
        CGPoint badgePoint = [self convertPoint:point toView:_dockBadge];
        if ([_dockBadge pointInside:badgePoint withEvent:event]) {
            return [_dockBadge hitTest:badgePoint withEvent:event];
        }
        return nil;
    }
    
    if (self.contentView) {
        CGPoint contentPoint = [self convertPoint:point toView:self.contentView];
        if ([self.contentView pointInside:contentPoint withEvent:event]) {
            if (_isFocused) {
                UIView *hitView = [self.contentView hitTest:contentPoint withEvent:event];
                return hitView ?: self.contentView;
            } else {
                return self;
            }
        }
    }
    
    // 触摸穿透模式优化：焦点状态下点击外部也直接穿透
    if (g_touchPassthroughMode) {
        return nil;
    }
    
    if (_isFocused) return self;
    return nil;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    
    if (self.contentView && !self.contentView.hidden) {
        CGPoint contentPoint = [self convertPoint:point toView:self.contentView];
        if ([self.contentView pointInside:contentPoint withEvent:event]) {
            _dragStartPoint = point;
            _contentStartCenter = self.contentView.center;
            if (!_isFocused) [self setFocused:YES animated:YES];
            return;
        }
    }
    
    if (_isFocused) [self setFocused:NO animated:YES];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.contentView || self.contentView.hidden || !_isFocused) return;
    
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    CGFloat dx = point.x - _dragStartPoint.x;
    CGFloat dy = point.y - _dragStartPoint.y;
    CGPoint newCenter = CGPointMake(_contentStartCenter.x + dx, _contentStartCenter.y + dy);
    
    CGFloat halfW = self.contentView.frame.size.width / 2;
    CGFloat halfH = self.contentView.frame.size.height / 2;
    CGFloat safeTop = [VLDockBadge safeTopMargin];
    
    newCenter.x = MAX(halfW - 50, MIN(self.bounds.size.width - halfW + 50, newCenter.x));
    newCenter.y = MAX(safeTop + halfH, MIN(self.bounds.size.height - halfH + 30, newCenter.y));
    
    self.contentView.center = newCenter;
}

- (void)setFocused:(BOOL)focused animated:(BOOL)animated {
    if (_isFocused == focused) return;
    _isFocused = focused;
    
    void (^animations)(void) = ^{
        if (focused) {
            self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
            self.contentView.alpha = 1.0;
        } else {
            self.backgroundColor = [UIColor clearColor];
            self.contentView.alpha = 0.3;
        }
    };
    
    if (animated) [UIView animateWithDuration:0.25 animations:animations];
    else animations();
}

@end
