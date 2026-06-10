/**
 * VansonLoader L2.3 - VLMemResults 实现
 * 内存搜索结果独立窗口
 * 支持拖动、缩小、避开灵动岛
 */

#import "VLMemResults.h"
#import "VLPanelSizeHelper.h"
#import "VLMemoryBrowser.h"
#import "VLWatchOverlay.h"
#import "VLToolbox.h"
#import "VLDockBadge.h"
#import "../Engine/VLMemEngine.h"
#import "../Engine/VLDebugEngine.h"
#import "../Utils/VLLocalization.h"
#import "../Utils/VLIconManager.h"
#import <objc/runtime.h>

UIWindow *GetSafeWindow(void);
void showToast(NSString *msg);

extern VMemDataType g_currentType;

// 触摸穿透模式（在 VLTools.m 中定义）
extern BOOL g_touchPassthroughMode;

static VMemDataType VLMemResultsNearbyTypeForSelection(NSInteger index) {
    switch (index) {
        case 0: return VMemDataTypeI8;
        case 1: return VMemDataTypeI16;
        case 2: return VMemDataTypeI32;
        case 3: return VMemDataTypeI64;
        case 4: return VMemDataTypeF32;
        case 5: return VMemDataTypeF64;
        default: return VMemDataTypeI32;
    }
}

static NSInteger VLMemResultsNearbySelectionForCurrentType(void) {
    switch (g_currentType) {
        case VMemDataTypeI8: return 0;
        case VMemDataTypeI16: return 1;
        case VMemDataTypeI32: return 2;
        case VMemDataTypeI64: return 3;
        case VMemDataTypeF32: return 4;
        case VMemDataTypeF64: return 5;
        default: return 2;
    }
}

#pragma mark - VLMemResultsContainerView

@interface VLMemResultsContainerView : UIView
@property (nonatomic, weak) UIView *contentView;
@property (nonatomic, assign) BOOL isFocused;
@property (nonatomic, assign) CGPoint dragStartPoint;
@property (nonatomic, assign) CGPoint contentStartCenter;
@property (nonatomic, strong) VLDockBadge *dockBadge;
- (void)setFocused:(BOOL)focused animated:(BOOL)animated;
- (void)minimize;
- (void)restore;
@end

@implementation VLMemResultsContainerView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _isFocused = YES;
        [self setupDockBadge];
    }
    return self;
}

- (void)setupDockBadge {
    _dockBadge = [[VLDockBadge alloc] initWithImage:IC(@"memory_results") fallbackIcon:@"📋"];
    _dockBadge.hidden = YES;
    __weak typeof(self) weakSelf = self;
    _dockBadge.onTap = ^{
        [weakSelf restore];
    };
    [self addSubview:_dockBadge];
}

- (void)minimize {
    if (!_contentView) return;
    
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

- (void)restore {
    _contentView.hidden = NO;
    [_dockBadge hideAnimated:YES];
    
    [UIView animateWithDuration:0.3 animations:^{
        self.contentView.alpha = 1;
        self.contentView.transform = CGAffineTransformIdentity;
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    } completion:^(BOOL finished) {
        self->_isFocused = YES;
        // 恢复时自动刷新数据
        [[NSNotificationCenter defaultCenter] postNotificationName:@"VLMemResultsDidRestore" object:nil];
    }];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.01) return nil;
    
    // 缩小状态：只响应角标
    if (_contentView.hidden && !_dockBadge.hidden) {
        CGPoint badgePoint = [self convertPoint:point toView:_dockBadge];
        if ([_dockBadge pointInside:badgePoint withEvent:event]) {
            return [_dockBadge hitTest:badgePoint withEvent:event];
        }
        return nil;
    }
    
    if (_contentView) {
        CGPoint contentPoint = [self convertPoint:point toView:_contentView];
        if ([_contentView pointInside:contentPoint withEvent:event]) {
            if (_isFocused) {
                UIView *hitView = [_contentView hitTest:contentPoint withEvent:event];
                return hitView ?: _contentView;
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
    
    if (_contentView && !_contentView.hidden) {
        CGPoint contentPoint = [self convertPoint:point toView:_contentView];
        if ([_contentView pointInside:contentPoint withEvent:event]) {
            _dragStartPoint = point;
            _contentStartCenter = _contentView.center;
            if (!_isFocused) [self setFocused:YES animated:YES];
            return;
        }
    }
    if (_isFocused) [self setFocused:NO animated:YES];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_contentView || _contentView.hidden || !_isFocused) return;
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    CGFloat dx = point.x - _dragStartPoint.x;
    CGFloat dy = point.y - _dragStartPoint.y;
    CGPoint newCenter = CGPointMake(_contentStartCenter.x + dx, _contentStartCenter.y + dy);
    
    CGFloat halfW = _contentView.frame.size.width / 2;
    CGFloat halfH = _contentView.frame.size.height / 2;
    CGFloat safeTop = [VLDockBadge safeTopMargin];
    
    newCenter.x = MAX(halfW - 50, MIN(self.bounds.size.width - halfW + 50, newCenter.x));
    newCenter.y = MAX(safeTop + halfH, MIN(self.bounds.size.height - halfH + 30, newCenter.y));
    _contentView.center = newCenter;
}

- (void)setFocused:(BOOL)focused animated:(BOOL)animated {
    if (_isFocused == focused) return;
    _isFocused = focused;
    void (^animations)(void) = ^{
        if (focused) {
            self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
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


#pragma mark - VLMemResultsImpl

@interface VLMemResultsImpl : NSObject <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) VLMemResultsContainerView *containerView;
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UIButton *refreshBtn;
@property (nonatomic, strong) NSMutableArray<VMemResultItem *> *displayResults;
@property (nonatomic, strong) NSMutableDictionary *lockedItems;
@property (nonatomic, strong) NSMutableDictionary *searchValues; // 搜索时的原始值，用于比较变化
@property (nonatomic, strong) NSTimer *lockTimer;
@property (nonatomic, strong) NSTimer *refreshTimer;
@end

static VLMemResultsImpl *g_memResults = nil;

@implementation VLMemResultsImpl

- (VMemDataType)displayTypeForItem:(VMemResultItem *)item {
    if (!item) return g_currentType;
    return item.type <= VMemDataTypeString ? item.type : g_currentType;
}

- (VMemDataType)displayTypeForAddress:(uint64_t)address fallback:(VMemDataType)fallbackType {
    for (VMemResultItem *item in _displayResults) {
        if (item.address == address) {
            return [self displayTypeForItem:item];
        }
    }
    return fallbackType;
}

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_memResults = [[VLMemResultsImpl alloc] init];
    });
    return g_memResults;
}

- (instancetype)init {
    if (self = [super init]) {
        _displayResults = [NSMutableArray array];
        _lockedItems = [NSMutableDictionary dictionary];
        _searchValues = [NSMutableDictionary dictionary];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLanguageChanged) name:@"VansonLanguageChanged" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onResultsRestore) name:@"VLMemResultsDidRestore" object:nil];
        // 提前触发 VLToolbox +initialize，确保锁定通知监听器在锁定按钮可用之前注册
        (void)[VLToolbox class];
    }
    return self;
}

- (void)dealloc {
    [_lockTimer invalidate];
    [_refreshTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)showInWindow:(UIWindow *)window {
    if (_containerView.superview && !_containerView.hidden && !_panelView.hidden) {
        [self loadResults];
        return;
    }
    
    if (!_containerView) {
        [self setupUI];
    }
    
    _containerView.frame = window.bounds;
    _containerView.hidden = NO;
    _panelView.hidden = NO;
    _containerView.alpha = 0;
    
    if (!_containerView.superview) {
        [window addSubview:_containerView];
    }
    [window bringSubviewToFront:_containerView];
    
    [self loadResults];
    [self startTimers];
    
    _panelView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:0 animations:^{
        self->_containerView.alpha = 1;
        self->_panelView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)showMinimizedInWindow:(UIWindow *)window {
    if (!_containerView) {
        [self setupUI];
    }
    
    _containerView.frame = window.bounds;
    _containerView.hidden = NO;
    _containerView.alpha = 1;
    _containerView.backgroundColor = [UIColor clearColor];
    
    // 直接设置为收起状态
    _panelView.hidden = YES;
    _containerView.isFocused = NO;
    
    if (!_containerView.superview) {
        [window addSubview:_containerView];
    }
    
    [self startTimers];
    
    // 直接显示悬浮图标
    [_containerView.dockBadge showInQueueInView:_containerView];
}

- (void)hide {
    [UIView animateWithDuration:0.2 animations:^{
        self->_panelView.transform = CGAffineTransformMakeScale(0.9, 0.9);
        self->_containerView.alpha = 0;
    } completion:^(BOOL finished) {
        self->_containerView.hidden = YES;
        self->_panelView.transform = CGAffineTransformIdentity;
        CGFloat sw = self->_containerView.bounds.size.width;
        CGFloat sh = self->_containerView.bounds.size.height;
        self->_panelView.center = CGPointMake(sw / 2, sh / 2);
        // 通知开关同步
        [[NSNotificationCenter defaultCenter] postNotificationName:@"VLWindowDidCloseNotification"
                                                            object:nil
                                                          userInfo:@{@"tag": @1004}];
    }];
}

- (BOOL)isVisible {
    return _containerView && _containerView.superview && !_containerView.hidden && !_panelView.hidden;
}

- (void)setupUI {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    _containerView = [[VLMemResultsContainerView alloc] initWithFrame:screenBounds];
    _containerView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    
    CGFloat sw = screenBounds.size.width;
    CGFloat sh = screenBounds.size.height;
    CGFloat w = MIN(sw * 0.88, 340);
    CGFloat h = MIN(sh * 0.55, 400);
    
    _panelView = [[UIView alloc] initWithFrame:CGRectMake((sw - w) / 2, (sh - h) / 2, w, h)];
    _panelView.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:0.96];
    _panelView.layer.cornerRadius = 14;
    _panelView.layer.borderWidth = 1.5;
    _panelView.layer.borderColor = [UIColor cyanColor].CGColor;
    _panelView.layer.shadowColor = [UIColor cyanColor].CGColor;
    _panelView.layer.shadowRadius = 15;
    _panelView.layer.shadowOpacity = 0.3;
    [_containerView addSubview:_panelView];
    _containerView.contentView = _panelView;

    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, w - 110, 24)];
    title.text = VL(@"Mem_Results");
    title.font = [UIFont fontWithName:@"Menlo-Bold" size:15];
    title.textColor = [UIColor cyanColor];
    title.tag = 1001;
    [_panelView addSubview:title];
    
    // 结果数量
    _countLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - 130, 8, 60, 24)];
    _countLabel.font = [UIFont fontWithName:@"Menlo" size:11];
    _countLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.6];
    _countLabel.textAlignment = NSTextAlignmentRight;
    [_panelView addSubview:_countLabel];
    
    UIButton *timelineBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    timelineBtn.frame = CGRectMake(w - 70, 6, 30, 30);
    [timelineBtn setTitle:@"↺" forState:UIControlStateNormal];
    [timelineBtn setTitleColor:[[UIColor cyanColor] colorWithAlphaComponent:0.7] forState:UIControlStateNormal];
    timelineBtn.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    [timelineBtn addTarget:self action:@selector(showTimelineSheet) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:timelineBtn];

    // 搜索结果窗口不需要关闭按钮（与内存调试双生）
    // 只保留最小化按钮
    UIButton *minBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    minBtn.frame = CGRectMake(w - 36, 6, 30, 30);
    [minBtn setTitle:@"−" forState:UIControlStateNormal];
    [minBtn setTitleColor:[[UIColor cyanColor] colorWithAlphaComponent:0.6] forState:UIControlStateNormal];
    minBtn.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [minBtn addTarget:self action:@selector(minimize) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:minBtn];
    
    // 大中小缩放按钮
    VLPanelAddSizeButtons(_panelView, screenBounds, w, h);
    
    // 列表
    CGFloat listTop = 38;
    CGFloat listH = h - listTop - 50; // 留出底部刷新按钮空间
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(6, listTop, w - 12, listH) style:UITableViewStylePlain];
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 52;
    _tableView.layer.cornerRadius = 8;
    [_panelView addSubview:_tableView];
    
    // 底部按钮栏: 附近搜索 + 刷新
    CGFloat btnBarW = (w - 36) / 2;

    UIButton *nearbyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    nearbyBtn.frame = CGRectMake(12, h - 42, btnBarW, 32);
    nearbyBtn.tag = 1010;
    [nearbyBtn setTitle:VL(@"Nearby_Btn") forState:UIControlStateNormal];
    [nearbyBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    nearbyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    nearbyBtn.layer.borderColor = [UIColor cyanColor].CGColor;
    nearbyBtn.layer.borderWidth = 1;
    nearbyBtn.layer.cornerRadius = 16;
    nearbyBtn.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.08];
    [nearbyBtn addTarget:self action:@selector(onNearbySearch) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:nearbyBtn];

    _refreshBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _refreshBtn.frame = CGRectMake(w / 2 + 6, h - 42, btnBarW, 32);
    [_refreshBtn setTitle:VL(@"Refresh_Btn") forState:UIControlStateNormal];
    [_refreshBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    _refreshBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    _refreshBtn.layer.borderColor = [UIColor cyanColor].CGColor;
    _refreshBtn.layer.borderWidth = 1;
    _refreshBtn.layer.cornerRadius = 16;
    _refreshBtn.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.08];
    [_refreshBtn addTarget:self action:@selector(onRefresh) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:_refreshBtn];
}

- (void)onLanguageChanged {
    for (UIView *v in _panelView.subviews) {
        if ([v isKindOfClass:[UILabel class]] && v.tag == 1001) {
            ((UILabel *)v).text = VL(@"Mem_Results");
        }
    }
    [_refreshBtn setTitle:VL(@"Refresh_Btn") forState:UIControlStateNormal];
    UIButton *nearbyBtn = [_panelView viewWithTag:1010];
    [nearbyBtn setTitle:VL(@"Nearby_Btn") forState:UIControlStateNormal];
    [_tableView reloadData];
}

- (void)onResultsRestore {
    // 恢复时自动刷新数据
    [self loadResults];
}

- (void)onRefresh {
    [self loadResults];
}

- (NSString *)timelineTypeName:(VMemDataType)type {
    NSArray *names = @[@"I8", @"I16", @"I32", @"I64", @"U8", @"U16", @"U32", @"U64", @"F32", @"F64", @"Str"];
    if (type < names.count) return names[type];
    return @"?";
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
                [self loadResults];
                showToast([NSString stringWithFormat:VL(@"Timeline_Restored_Fmt"), time, (unsigned long)item.resultCount]);
                [[NSNotificationCenter defaultCenter] postNotificationName:@"VLMemResultsDidRestore" object:nil];
            } else {
                showToast(VL(@"Timeline_Restore_Failed"));
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

- (void)onNearbySearch {
    NSUInteger total = [VMemEngine shared].resultCount;
    if (total == 0) {
        showToast(VL(@"Mem_NoResults"));
        return;
    }

    UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"Nearby_Title")
                                                               message:@"\n\n\n"
                                                        preferredStyle:UIAlertControllerStyleAlert];
    UISegmentedControl *typeSeg = [[UISegmentedControl alloc] initWithItems:@[@"I8", @"I16", @"I32", @"I64", @"F32", @"F64"]];
    typeSeg.frame = CGRectMake(12, 52, 246, 28);
    typeSeg.selectedSegmentIndex = VLMemResultsNearbySelectionForCurrentType();
    typeSeg.selectedSegmentTintColor = [[UIColor cyanColor] colorWithAlphaComponent:0.18];
    [typeSeg setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [UIColor cyanColor],
        NSFontAttributeName: [UIFont boldSystemFontOfSize:10]
    } forState:UIControlStateNormal];
    [ac.view addSubview:typeSeg];

    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = VL(@"Nearby_Value");
        tf.keyboardType = UIKeyboardTypeDecimalPad;
        tf.font = [UIFont fontWithName:@"Menlo" size:14];
    }];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = VL(@"Nearby_Range");
        tf.text = @"512";
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.font = [UIFont fontWithName:@"Menlo" size:14];
    }];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Btn_Search") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *valueStr = ac.textFields[0].text;
        NSString *rangeStr = ac.textFields[1].text;
        if (!valueStr || valueStr.length == 0) {
            showToast(VL(@"Mem_InputRequired"));
            return;
        }
        uint64_t range = 512;
        if (rangeStr.length > 0) {
            range = strtoull(rangeStr.UTF8String, NULL, 10);
            if (range == 0) range = 512;
        }
        g_currentType = VLMemResultsNearbyTypeForSelection(typeSeg.selectedSegmentIndex);

        showToast(VL(@"Mem_Searching"));
        [[VMemEngine shared] scanNearbyWithValue:valueStr
                                            type:g_currentType
                                           range:range
                                      completion:^(NSUInteger count, NSString *msg) {
            if (count > 0) {
                NSString *detail = [NSString stringWithFormat:@"%@ %@",
                                                              [self timelineTypeName:g_currentType],
                                                              valueStr ?: @""];
                [[VMemEngine shared] captureTimelineWithTitle:VL(@"Nearby_Btn")
                                                       detail:detail
                                                     dataType:g_currentType];
                showToast([NSString stringWithFormat:@"%@ %lu", VL(@"Mem_Found"), (unsigned long)count]);
            } else {
                showToast(VL(@"Msg_NoResult"));
            }
            [self->_searchValues removeAllObjects];
            [self loadResults];
            [VLMemResults notifyResultsUpdated];
        }];
    }]];

    UIViewController *root = GetSafeWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:ac animated:YES completion:nil];
}

- (void)close {
    // 搜索结果窗口不允许单独关闭，只能通过内存调试窗口关闭
    // 这里改为最小化
    [self minimize];
}

- (void)minimize {
    [_containerView minimize];
}

- (void)startTimers {
    if (!_lockTimer) {
        _lockTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateLocks) userInfo:nil repeats:YES];
    }
    if (!_refreshTimer) {
        _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(refreshValues) userInfo:nil repeats:YES];
    }
}

- (void)updateLocks {
    VMemEngine *engine = [VMemEngine shared];
    if (!engine.isReady) return;
    for (NSNumber *addrNum in _lockedItems) {
        uint64_t addr = [addrNum unsignedLongLongValue];
        NSString *val = _lockedItems[addrNum];
        VMemDataType type = [self displayTypeForAddress:addr fallback:g_currentType];
        [engine writeAddress:addr value:val type:type];
    }
}

- (void)refreshValues {
    if (_containerView.hidden || _panelView.hidden) return;
    VMemEngine *engine = [VMemEngine shared];
    if (!engine.isReady) return;
    BOOL needsReload = NO;
    for (VMemResultItem *item in _displayResults) {
        NSString *newVal = [engine readAddress:item.address type:[self displayTypeForItem:item]];
        if (newVal && ![newVal isEqualToString:item.valueStr]) {
            item.valueStr = newVal;
            needsReload = YES;
        }
    }
    if (needsReload) [_tableView reloadData];
}

- (void)loadResults {
    [_displayResults removeAllObjects];
    NSUInteger total = [VMemEngine shared].resultCount;
    NSUInteger count = MIN(total, 100);
    
    // 首次加载时保存搜索值
    BOOL isFirstLoad = (_searchValues.count == 0);
    
    for (NSUInteger i = 0; i < count; i++) {
        VMemResultItem *item = [[VMemEngine shared] getResultAtIndex:i type:g_currentType];
        if (item) {
            // 直接从内存读取最新值
            NSString *freshValue = [[VMemEngine shared] readAddress:item.address type:[self displayTypeForItem:item]];
            if (freshValue) {
                item.valueStr = freshValue;
            }
            [_displayResults addObject:item];
            // 保存搜索时的原始值
            if (isFirstLoad && item.valueStr) {
                _searchValues[@(item.address)] = item.valueStr;
            }
        }
    }
    _countLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)total];
    [_tableView reloadData];
}

// 清除搜索值缓存（新搜索时调用）
- (void)clearSearchValues {
    [_searchValues removeAllObjects];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _displayResults.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"VLMemResultCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.05];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.layer.cornerRadius = 6;
        
        // 地址标签 (左上)
        UILabel *addrLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, 140, 18)];
        addrLabel.textColor = [UIColor cyanColor];
        addrLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:12];
        addrLabel.tag = 101;
        [cell.contentView addSubview:addrLabel];
        
        // 类型标签 (左下)
        UILabel *typeLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 28, 40, 16)];
        typeLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.5];
        typeLabel.font = [UIFont fontWithName:@"Menlo" size:10];
        typeLabel.tag = 102;
        [cell.contentView addSubview:typeLabel];
        
        // 数值标签 (锁定按钮左边)
        UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        valueLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.9];
        valueLabel.font = [UIFont fontWithName:@"Menlo" size:13];
        valueLabel.textAlignment = NSTextAlignmentRight;
        valueLabel.tag = 103;
        [cell.contentView addSubview:valueLabel];
        
        // 查看按钮 (锁定按钮左边)
        UIButton *viewBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        viewBtn.titleLabel.font = [UIFont systemFontOfSize:11];
        viewBtn.tag = 104;
        [cell.contentView addSubview:viewBtn];
        
        // 监控按钮 (仅越狱环境)
        UIButton *watchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        watchBtn.titleLabel.font = [UIFont systemFontOfSize:11];
        watchBtn.tag = 105;
        [cell.contentView addSubview:watchBtn];
        
        // 锁定按钮 (最右边)
        UIButton *lockBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        lockBtn.titleLabel.font = [UIFont systemFontOfSize:11];
        lockBtn.tag = 100;
        [cell.contentView addSubview:lockBtn];
    }
    
    VMemResultItem *item = _displayResults[indexPath.row];
    BOOL isLocked = _lockedItems[@(item.address)] != nil;
    
    // 获取子视图
    UILabel *addrLabel = [cell.contentView viewWithTag:101];
    UILabel *typeLabel = [cell.contentView viewWithTag:102];
    UILabel *valueLabel = [cell.contentView viewWithTag:103];
    UIButton *viewBtn = [cell.contentView viewWithTag:104];
    UIButton *watchBtn = [cell.contentView viewWithTag:105];
    UIButton *lockBtn = [cell.contentView viewWithTag:100];
    
    // 设置内容
    addrLabel.text = [NSString stringWithFormat:@"0x%llX", item.address];
    
    // 类型名称
    NSArray *typeNames = @[@"I8", @"I16", @"I32", @"I64", @"U8", @"U16", @"U32", @"U64", @"F32", @"F64", @"Str"];
    VMemDataType displayType = [self displayTypeForItem:item];
    typeLabel.text = displayType < typeNames.count ? typeNames[displayType] : @"?";
    
    valueLabel.text = item.valueStr ?: @"--";
    
    // 数值变化标红：比较当前值与搜索时的原始值
    NSString *searchValue = _searchValues[@(item.address)];
    if (searchValue && item.valueStr && ![item.valueStr isEqualToString:searchValue]) {
        valueLabel.textColor = [UIColor systemRedColor]; // 值已变化，标红
    } else {
        valueLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.9]; // 正常颜色
    }
    
    // 布局调整 - 使用 tableView 宽度而不是 cell 宽度
    CGFloat cellW = tableView.bounds.size.width - 12; // tableView 有 6pt 左右边距
    BOOL isStringType = (displayType == VMemDataTypeString);
    
    if (isStringType) {
        // String: 隐藏 lock/watch，value 占满右侧
        lockBtn.hidden = YES;
        watchBtn.hidden = YES;
        CGFloat viewBtnW = 40;
        viewBtn.frame = CGRectMake(cellW - viewBtnW - 8, 11, viewBtnW, 30);
        CGFloat valueLabelW = cellW - 150 - viewBtnW - 16;
        valueLabel.frame = CGRectMake(150, 11, valueLabelW, 30);
        valueLabel.textAlignment = NSTextAlignmentLeft;
        valueLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    } else {
        lockBtn.hidden = NO;
        CGFloat lockBtnW = 50;
        CGFloat viewBtnW = 40;
        CGFloat watchBtnW = [VLDebugEngine isAvailable] ? 40 : 0;
        CGFloat valueLabelW = 70;
        lockBtn.frame = CGRectMake(cellW - lockBtnW - 8, 11, lockBtnW, 30);
        viewBtn.frame = CGRectMake(cellW - lockBtnW - viewBtnW - 12, 11, viewBtnW, 30);
        watchBtn.frame = CGRectMake(cellW - lockBtnW - viewBtnW - watchBtnW - 16, 11, watchBtnW, 30);
        valueLabel.frame = CGRectMake(cellW - lockBtnW - viewBtnW - watchBtnW - valueLabelW - 24, 11, valueLabelW, 30);
        valueLabel.textAlignment = NSTextAlignmentRight;
    }
    
    // Watch 按钮 (仅越狱环境显示, String模式下隐藏)
    if (!isStringType) watchBtn.hidden = ![VLDebugEngine isAvailable];
    if (!watchBtn.hidden) {
        [watchBtn setTitle:VL(@"Watch_Btn") forState:UIControlStateNormal];
        [watchBtn setTitleColor:[[UIColor cyanColor] colorWithAlphaComponent:0.7] forState:UIControlStateNormal];
        objc_setAssociatedObject(watchBtn, "itemAddress", @(item.address), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [watchBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [watchBtn addTarget:self action:@selector(onWatchTapped:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    // 锁定状态
    cell.backgroundColor = isLocked ? [[UIColor cyanColor] colorWithAlphaComponent:0.15] : [[UIColor cyanColor] colorWithAlphaComponent:0.05];
    
    [lockBtn setTitle:isLocked ? VL(@"UI_Locked") : VL(@"UI_Unlocked") forState:UIControlStateNormal];
    [lockBtn setTitleColor:isLocked ? [UIColor cyanColor] : [[UIColor cyanColor] colorWithAlphaComponent:0.6] forState:UIControlStateNormal];
    
    // 查看按钮
    [viewBtn setTitle:VL(@"Btn_View") forState:UIControlStateNormal];
    [viewBtn setTitleColor:[[UIColor cyanColor] colorWithAlphaComponent:0.7] forState:UIControlStateNormal];
    
    // 使用 objc_setAssociatedObject 存储地址，避免 tag 复用问题
    objc_setAssociatedObject(lockBtn, "itemAddress", @(item.address), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [lockBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [lockBtn addTarget:self action:@selector(onLockTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    objc_setAssociatedObject(viewBtn, "itemAddress", @(item.address), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [viewBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [viewBtn addTarget:self action:@selector(onViewTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    return cell;
}

- (void)onLockTapped:(UIButton *)sender {
    // 使用 associated object 获取地址，避免 cell 复用导致的 tag 问题
    NSNumber *addrNum = objc_getAssociatedObject(sender, "itemAddress");
    if (!addrNum) return;
    
    uint64_t address = [addrNum unsignedLongLongValue];
    NSNumber *addrKey = @(address);
    
    // 查找对应的 item
    VMemResultItem *item = nil;
    NSInteger idx = -1;
    for (NSInteger i = 0; i < _displayResults.count; i++) {
        if (_displayResults[i].address == address) {
            item = _displayResults[i];
            idx = i;
            break;
        }
    }
    if (!item || idx < 0) return;
    
    if (_lockedItems[addrKey]) {
        [_lockedItems removeObjectForKey:addrKey];
        showToast(VL(@"Msg_Unlocked"));
        
        // 发送解锁通知到工具箱
        [[NSNotificationCenter defaultCenter] postNotificationName:@"VMemItemUnlockedFromPanel"
                                                            object:nil
                                                          userInfo:@{@"address": @(item.address)}];
    } else {
        _lockedItems[addrKey] = item.valueStr ?: @"0";
        showToast(VL(@"Msg_Locked"));
        
        // 发送通知到工具箱
        [[NSNotificationCenter defaultCenter] postNotificationName:@"VMemItemLockedToPanel"
                                                            object:nil
                                                          userInfo:@{@"item": @{
                                                              @"address": @(item.address),
                                                              @"dataType": @(g_currentType),
                                                              @"currentValue": item.valueStr ?: @"0"
                                                          }}];
    }
    [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)onWatchTapped:(UIButton *)sender {
    NSLog(@"[VLDebug-ObjC] onWatchTapped");
    NSNumber *addrNum = objc_getAssociatedObject(sender, "itemAddress");
    if (!addrNum) return;
    uint64_t address = [addrNum unsignedLongLongValue];
    NSLog(@"[VLDebug-ObjC] calling addWatchForAddress: 0x%llX", address);
    [VLWatchOverlay addWatchForAddress:address];
    // 自动打开断点监控面板，让用户能看到断点列表
    if (![VLWatchOverlay isVisible]) {
        [VLWatchOverlay show];
    }
}

- (void)onViewTapped:(UIButton *)sender {
    NSNumber *addrNum = objc_getAssociatedObject(sender, "itemAddress");
    if (!addrNum) return;
    
    uint64_t address = [addrNum unsignedLongLongValue];
    
    // 打开内存浏览器并跳转到该地址
    [VLMemoryBrowserVC showWithAddress:address];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= _displayResults.count) return;
    VMemResultItem *item = _displayResults[indexPath.row];
    [self showEditAlertForItem:item atIndex:indexPath.row];
}

- (NSUInteger)writeSizeForType:(VMemDataType)type oldValue:(NSString *)oldValue newValue:(NSString *)newValue {
    switch (type) {
        case VMemDataTypeI8:
        case VMemDataTypeU8:
            return 1;
        case VMemDataTypeI16:
        case VMemDataTypeU16:
            return 2;
        case VMemDataTypeI64:
        case VMemDataTypeU64:
        case VMemDataTypeF64:
            return 8;
        case VMemDataTypeString: {
            NSUInteger oldLen = [oldValue lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            NSUInteger newLen = [newValue lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            return MAX((NSUInteger)1, MAX(oldLen, newLen));
        }
        case VMemDataTypeI32:
        case VMemDataTypeU32:
        case VMemDataTypeF32:
        default:
            return 4;
    }
}

- (void)showEditAlertForItem:(VMemResultItem *)item atIndex:(NSInteger)index {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"0x%llX", item.address] message:nil preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = item.valueStr;
        tf.keyboardType = UIKeyboardTypeDecimalPad;
        tf.placeholder = VL(@"Mem_NewValue");
    }];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    VMemDataType itemType = [self displayTypeForItem:item];
    VLMemWriteUndoItem *undo = [[VMemEngine shared] lastManualWriteUndoForAddress:item.address type:itemType];
    if (undo) {
        NSString *undoTitle = [NSString stringWithFormat:@"%@: %@", VL(@"Undo_Last_Modify"), undo.oldValue ?: @""];
        [ac addAction:[UIAlertAction actionWithTitle:undoTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            BOOL ok = [[VMemEngine shared] undoLastManualWriteForAddress:item.address type:itemType];
            if (ok) {
                item.valueStr = undo.oldValue;
                [self->_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
                showToast(VL(@"Undo_Success"));
            } else {
                showToast(VL(@"Undo_Failed"));
            }
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Mem_Write") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *newVal = ac.textFields.firstObject.text;
        if (newVal.length > 0) {
            NSString *oldVal = [[VMemEngine shared] readAddress:item.address type:itemType];
            NSUInteger oldSize = [self writeSizeForType:itemType oldValue:oldVal newValue:newVal];
            NSData *oldData = [[VMemEngine shared] readMemory:item.address length:oldSize];
            [[VMemEngine shared] rememberManualWriteUndoAtAddress:item.address
                                                            type:itemType
                                                        oldValue:oldVal
                                                         oldData:oldData
                                                        newValue:newVal];
            BOOL ok = [[VMemEngine shared] writeAddress:item.address value:newVal type:itemType];
            if (ok) {
                item.valueStr = newVal;
                if (self->_lockedItems[@(item.address)]) {
                    self->_lockedItems[@(item.address)] = newVal;
                }
                [self->_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
                showToast(VL(@"Mem_WriteOK"));
            } else {
                showToast(VL(@"Mem_WriteFail"));
            }
        }
    }]];
    
    UIViewController *root = GetSafeWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:ac animated:YES completion:nil];
}

@end


#pragma mark - VLMemResults

@implementation VLMemResults

+ (void)show {
    UIWindow *w = GetSafeWindow();
    if (!w) return;
    [[VLMemResultsImpl shared] showInWindow:w];
}

+ (void)showMinimized {
    UIWindow *w = GetSafeWindow();
    if (!w) return;
    [[VLMemResultsImpl shared] showMinimizedInWindow:w];
}

+ (void)hide {
    [[VLMemResultsImpl shared] hide];
}

+ (void)toggle {
    VLMemResultsImpl *impl = [VLMemResultsImpl shared];
    if ([impl isVisible]) {
        [impl hide];
    } else {
        [self show];
    }
}

+ (BOOL)isVisible {
    return [[VLMemResultsImpl shared] isVisible];
}

+ (void)reloadData {
    [[VLMemResultsImpl shared] loadResults];
}

+ (void)notifyResultsUpdated {
    NSUInteger count = [VMemEngine shared].resultCount;
    if (count > 0) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Vanson_MemResults_Enabled"]) {
            [VLMemResults show];
        }
        if ([self isVisible]) {
            [self reloadData];
        }
    }
}

@end
