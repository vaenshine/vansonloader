/**
 * VansonLoader L2.3 - VLToolbox 实现
 * 工具箱悬浮容器 (内存、指针、RVA、特征码、脚本)
 */

#import "VLToolbox.h"
#import "VLPanelSizeHelper.h"
#import "VLMemorySearch.h"
#import "VLPanel.h"
#import "VLDockBadge.h"
#import "../Engine/VLModEngine.h"
#import "../Engine/VLModParser.h"
#import "../Engine/VLMemEngine.h"
#import "../Engine/VLScriptEngine.h"
#import "../Models/VLScriptItem.h"
#import "../Utils/VLLocalization.h"
#import "../Utils/VLIconManager.h"
#import "VLModCell.h"
#import "VLItemEditor.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

// 全局数据
extern NSMutableArray<VModItem *> *g_ptrItems;
extern NSMutableArray<VModItem *> *g_rvaItems;
extern NSMutableArray<VModItem *> *g_sigItems;
extern NSMutableArray<VScriptItem *> *g_scriptItems;

UIWindow *GetSafeWindow(void);
void showToast(NSString *msg);

// 触摸穿透模式（在 VLTools.m 中定义）
extern BOOL g_touchPassthroughMode;

#pragma mark - VLToolboxContainerView (触摸穿透处理)

@interface VLToolboxContainerView : UIView
@property (nonatomic, weak) UIView *contentView;
@property (nonatomic, assign) BOOL isFocused;
@property (nonatomic, assign) BOOL isDocked;
@property (nonatomic, assign) CGPoint dragStartPoint;
@property (nonatomic, assign) CGPoint contentStartCenter;
@property (nonatomic, strong) VLDockBadge *dockBadge;
- (void)setFocused:(BOOL)focused animated:(BOOL)animated;
- (void)dockToEdge;
- (void)undock;
@end

@implementation VLToolboxContainerView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _isFocused = YES;
        _isDocked = NO;
        [self setupDockBadge];
    }
    return self;
}

- (void)setupDockBadge {
    _dockBadge = [[VLDockBadge alloc] initWithImage:IC(@"toolbox") fallbackIcon:@"🧰"];
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
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
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
    
    if (self.contentView) {
        CGPoint contentPoint = [self convertPoint:point toView:self.contentView];
        if ([self.contentView pointInside:contentPoint withEvent:event]) {
            _dragStartPoint = point;
            _contentStartCenter = self.contentView.center;
            if (!_isFocused) {
                [self setFocused:YES animated:YES];
            }
            return;
        }
    }
    
    if (_isFocused) {
        [self setFocused:NO animated:YES];
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.contentView || self.contentView.hidden || !_isFocused || _isDocked) return;
    
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    
    CGFloat dx = point.x - _dragStartPoint.x;
    CGFloat dy = point.y - _dragStartPoint.y;
    
    CGPoint newCenter = CGPointMake(_contentStartCenter.x + dx, _contentStartCenter.y + dy);
    
    CGFloat halfW = self.contentView.frame.size.width / 2;
    CGFloat halfH = self.contentView.frame.size.height / 2;
    CGFloat safeTop = 70; // 避开灵动岛
    if (@available(iOS 11.0, *)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
        if (window) {
            safeTop = MAX(window.safeAreaInsets.top + 15, 70);
        }
    }
    
    CGFloat minX = halfW - 50;
    CGFloat maxX = self.bounds.size.width - halfW + 50;
    CGFloat minY = safeTop + halfH;
    CGFloat maxY = self.bounds.size.height - halfH + 30;
    
    newCenter.x = MAX(minX, MIN(maxX, newCenter.x));
    newCenter.y = MAX(minY, MIN(maxY, newCenter.y));
    
    self.contentView.center = newCenter;
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
    
    if (animated) {
        [UIView animateWithDuration:0.25 animations:animations];
    } else {
        animations();
    }
}

@end

#pragma mark - VLToolboxImpl

@interface VLToolboxImpl : UIViewController <UITableViewDelegate, UITableViewDataSource, VLModCellDelegate, VLItemEditorDelegate, UIDocumentPickerDelegate, UITableViewDragDelegate, UITableViewDropDelegate>
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UISegmentedControl *tabSeg;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *refreshBtn;
@property (nonatomic, strong) UIButton *importBtn;
@property (nonatomic, strong) UIButton *snapshotBtn;
@property (nonatomic, strong) UILabel *pageLabel;
@property (nonatomic, strong) UIButton *prevBtn;
@property (nonatomic, strong) UIButton *nextBtn;
@property (nonatomic, assign) NSInteger currentTab; // 0=内存, 1=指针, 2=RVA, 3=特征码, 4=脚本
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) NSInteger itemsPerPage;
- (void)updatePanelHeight;
- (void)updatePageLabel;
@end

static VLToolboxImpl *g_toolbox = nil;
static NSMutableArray *g_toolboxMemResults = nil;
static NSTimer *g_toolboxLockTimer = nil;
static BOOL g_toolboxNotificationsRegistered = NO;

// 内存项模型 (复用)
@interface VLToolboxMemItem : NSObject
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, assign) VMemDataType dataType;
@property (nonatomic, copy) NSString *note;
@property (nonatomic, copy) NSString *currentValue;
@property (nonatomic, assign) BOOL isLocked;
@property (nonatomic, copy) NSString *lockValue;
@end

@implementation VLToolboxMemItem
@end

#pragma mark - 全局通知处理（确保工具箱未打开时也能接收锁定通知）

static void VLToolbox_OnMemItemLocked(NSNotification *notification) {
    NSDictionary *dict = notification.userInfo[@"item"];
    if (!dict) return;
    
    if (!g_toolboxMemResults) g_toolboxMemResults = [NSMutableArray array];
    
    uint64_t address = [dict[@"address"] unsignedLongLongValue];
    for (VLToolboxMemItem *existing in g_toolboxMemResults) {
        if (existing.address == address) {
            existing.isLocked = YES;
            existing.lockValue = dict[@"currentValue"];
            // 如果工具箱已打开，刷新UI
            if (g_toolbox) {
                [g_toolbox updatePanelHeight];
                [g_toolbox.tableView reloadData];
                [g_toolbox updatePageLabel];
            }
            return;
        }
    }
    
    VLToolboxMemItem *item = [[VLToolboxMemItem alloc] init];
    item.address = address;
    item.dataType = (VMemDataType)[dict[@"dataType"] unsignedIntegerValue];
    item.currentValue = dict[@"currentValue"];
    item.lockValue = dict[@"currentValue"];
    item.note = @"";
    item.isLocked = YES;
    [g_toolboxMemResults addObject:item];
    
    // 如果工具箱已打开，刷新UI
    if (g_toolbox) {
        [g_toolbox updatePanelHeight];
        [g_toolbox.tableView reloadData];
        [g_toolbox updatePageLabel];
    }
}

static void VLToolbox_OnMemItemUnlocked(NSNotification *notification) {
    uint64_t address = [notification.userInfo[@"address"] unsignedLongLongValue];
    
    if (!g_toolboxMemResults) return;
    
    VLToolboxMemItem *toRemove = nil;
    for (VLToolboxMemItem *item in g_toolboxMemResults) {
        if (item.address == address) {
            toRemove = item;
            break;
        }
    }
    
    if (toRemove) {
        [g_toolboxMemResults removeObject:toRemove];
        
        // 如果工具箱已打开，刷新UI
        if (g_toolbox) {
            NSInteger totalPages = (g_toolboxMemResults.count + g_toolbox.itemsPerPage - 1) / g_toolbox.itemsPerPage;
            if (totalPages == 0) totalPages = 1;
            if (g_toolbox.currentPage >= totalPages && g_toolbox.currentPage > 0) {
                g_toolbox.currentPage = totalPages - 1;
            }
            [g_toolbox updatePanelHeight];
            [g_toolbox.tableView reloadData];
            [g_toolbox updatePageLabel];
        }
    }
}

static void VLToolbox_RegisterGlobalNotifications(void) {
    if (g_toolboxNotificationsRegistered) return;
    g_toolboxNotificationsRegistered = YES;
    
    if (!g_toolboxMemResults) g_toolboxMemResults = [NSMutableArray array];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"VMemItemLockedToPanel"
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        VLToolbox_OnMemItemLocked(note);
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"VMemItemUnlockedFromPanel"
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        VLToolbox_OnMemItemUnlocked(note);
    }];
}

@implementation VLToolboxImpl

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_toolbox = [[VLToolboxImpl alloc] init];
    });
    return g_toolbox;
}

- (instancetype)init {
    if (self = [super init]) {
        if (!g_toolboxMemResults) g_toolboxMemResults = [NSMutableArray array];
        _currentPage = 0;
        _itemsPerPage = 3; // 默认每页3行，会根据屏幕自适应（3-5行）
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onLanguageChanged)
                                                     name:@"VansonLanguageChanged"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onMemResultsReceived:)
                                                     name:@"VMemResultsToPanel"
                                                   object:nil];
        // 注意：锁定/解锁通知已在全局函数中处理，这里不再重复监听
    }
    return self;
}

- (void)loadView {
    VLToolboxContainerView *container = [[VLToolboxContainerView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view = container;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    [self setupUI];
    
    if ([self.view isKindOfClass:[VLToolboxContainerView class]]) {
        ((VLToolboxContainerView *)self.view).contentView = _panelView;
    }
    
    // 锁定定时器
    g_toolboxLockTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                          target:self
                                                        selector:@selector(updateLocks)
                                                        userInfo:nil
                                                         repeats:YES];
}

- (void)setupUI {
    CGFloat sw = self.view.bounds.size.width;
    CGFloat sh = self.view.bounds.size.height;
    CGFloat w = 370;  // 固定宽度
    CGFloat h = 370;  // 最大高度，实际高度会根据内容自适应
    
    // 主面板 - 赛博朋克 cyan 风格
    _panelView = [[UIView alloc] initWithFrame:CGRectMake((sw - w) / 2, (sh - h) / 2, w, h)];
    _panelView.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:0.96];
    _panelView.layer.cornerRadius = 14;
    _panelView.layer.borderWidth = 1.5;
    _panelView.layer.borderColor = [UIColor cyanColor].CGColor;
    _panelView.layer.shadowColor = [UIColor cyanColor].CGColor;
    _panelView.layer.shadowRadius = 15;
    _panelView.layer.shadowOpacity = 0.3;
    [self.view addSubview:_panelView];
    
    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, w - 50, 24)];
    title.text = VL(@"Toolbox_Title");
    title.font = [UIFont fontWithName:@"Menlo-Bold" size:15];
    title.textColor = [UIColor cyanColor];
    title.tag = 100;
    [_panelView addSubview:title];
    
    // 最小化按钮 (子窗口只保留最小化，关闭由主窗口控制)
    UIButton *minBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    minBtn.frame = CGRectMake(w - 36, 6, 30, 30);
    [minBtn setTitle:@"−" forState:UIControlStateNormal];
    [minBtn setTitleColor:[[UIColor cyanColor] colorWithAlphaComponent:0.6] forState:UIControlStateNormal];
    minBtn.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    minBtn.tag = 101;
    [minBtn addTarget:self action:@selector(minimize) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:minBtn];

    // 大中小缩放按钮
    VLPanelAddSizeButtons(_panelView, self.view.bounds, w, h);

    // Tab 控件 - 5个固定Tab - cyan 风格
    NSArray *tabs = @[VL(@"Tab_Mem"), VL(@"Tab_Ptr"), VL(@"Tab_RVA"), VL(@"Tab_Sig"), VL(@"Tab_Script")];
    _tabSeg = [[UISegmentedControl alloc] initWithItems:tabs];
    _tabSeg.frame = CGRectMake(10, 38, w - 20, 28);
    _tabSeg.selectedSegmentIndex = 0;
    _tabSeg.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.1];
    _tabSeg.selectedSegmentTintColor = [UIColor cyanColor];
    [_tabSeg setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blackColor], NSFontAttributeName: [UIFont boldSystemFontOfSize:10]} forState:UIControlStateSelected];
    [_tabSeg setTitleTextAttributes:@{NSForegroundColorAttributeName: [[UIColor cyanColor] colorWithAlphaComponent:0.7], NSFontAttributeName: [UIFont systemFontOfSize:10]} forState:UIControlStateNormal];
    [_tabSeg addTarget:self action:@selector(tabChanged) forControlEvents:UIControlEventValueChanged];
    [_panelView addSubview:_tabSeg];
    
    // 列表 (高度会在 updatePanelHeight 中动态调整)
    CGFloat listTop = 74;
    CGFloat listH = h - listTop - 90; // 为分页和按钮留空间
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, listTop, w, listH) style:UITableViewStylePlain];
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 60;
    _tableView.scrollEnabled = NO; // 禁用滚动，使用分页
    _tableView.dragInteractionEnabled = YES;
    _tableView.dragDelegate = self;
    _tableView.dropDelegate = self;
    [_panelView addSubview:_tableView];
    
    // 分页控件
    CGFloat pageY = h - 82;
    _prevBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _prevBtn.frame = CGRectMake(12, pageY, 36, 28);
    [_prevBtn setTitle:@"◀" forState:UIControlStateNormal];
    [_prevBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    _prevBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    _prevBtn.layer.cornerRadius = 6;
    _prevBtn.layer.borderWidth = 1;
    _prevBtn.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.5].CGColor;
    _prevBtn.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.05];
    [_prevBtn addTarget:self action:@selector(prevPage) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:_prevBtn];
    
    _pageLabel = [[UILabel alloc] initWithFrame:CGRectMake(54, pageY, w - 108, 28)];
    _pageLabel.textAlignment = NSTextAlignmentCenter;
    _pageLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.7];
    _pageLabel.font = [UIFont fontWithName:@"Menlo" size:11];
    _pageLabel.text = @"1 / 1";
    [_panelView addSubview:_pageLabel];
    
    _nextBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _nextBtn.frame = CGRectMake(w - 48, pageY, 36, 28);
    [_nextBtn setTitle:@"▶" forState:UIControlStateNormal];
    [_nextBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    _nextBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    _nextBtn.layer.cornerRadius = 6;
    _nextBtn.layer.borderWidth = 1;
    _nextBtn.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.5].CGColor;
    _nextBtn.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.05];
    [_nextBtn addTarget:self action:@selector(nextPage) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:_nextBtn];
    
    // 底部按钮区域 - 导入 + 快照 + 刷新
    CGFloat btnW = 82;
    CGFloat btnSpacing = 8;
    CGFloat totalBtnW = btnW * 3 + btnSpacing * 2;
    CGFloat btnStartX = (w - totalBtnW) / 2;
    
    // 导入按钮
    _importBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _importBtn.frame = CGRectMake(btnStartX, h - 42, btnW, 32);
    [_importBtn setTitle:VL(@"Btn_Import") forState:UIControlStateNormal];
    [_importBtn setTitleColor:[UIColor systemGreenColor] forState:UIControlStateNormal];
    _importBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    _importBtn.layer.borderColor = [UIColor systemGreenColor].CGColor;
    _importBtn.layer.borderWidth = 1;
    _importBtn.layer.cornerRadius = 16;
    _importBtn.backgroundColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.08];
    [_importBtn addTarget:self action:@selector(onImport) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:_importBtn];

    _snapshotBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _snapshotBtn.frame = CGRectMake(btnStartX + btnW + btnSpacing, h - 42, btnW, 32);
    [_snapshotBtn setTitle:VL(@"Snapshot_Button") forState:UIControlStateNormal];
    [_snapshotBtn setTitleColor:[UIColor systemOrangeColor] forState:UIControlStateNormal];
    _snapshotBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    _snapshotBtn.layer.borderColor = [UIColor systemOrangeColor].CGColor;
    _snapshotBtn.layer.borderWidth = 1;
    _snapshotBtn.layer.cornerRadius = 16;
    _snapshotBtn.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:0.08];
    [_snapshotBtn addTarget:self action:@selector(onValueSnapshot) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:_snapshotBtn];
    
    // 刷新按钮 - cyan 风格
    _refreshBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _refreshBtn.frame = CGRectMake(btnStartX + (btnW + btnSpacing) * 2, h - 42, btnW, 32);
    [_refreshBtn setTitle:VL(@"Btn_Refresh") forState:UIControlStateNormal];
    [_refreshBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    _refreshBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    _refreshBtn.layer.borderColor = [UIColor cyanColor].CGColor;
    _refreshBtn.layer.borderWidth = 1;
    _refreshBtn.layer.cornerRadius = 16;
    _refreshBtn.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.08];
    [_refreshBtn addTarget:self action:@selector(onRefresh) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:_refreshBtn];
    
    // 初始更新面板高度
    [self updatePanelHeight];
}

- (void)tabChanged {
    _currentTab = _tabSeg.selectedSegmentIndex;
    _currentPage = 0; // 切换 tab 时重置页码
    _snapshotBtn.hidden = _currentTab != 0;
    [self updatePanelHeight];
    [_tableView reloadData];
    [self updatePageLabel];
}

- (void)onRefresh {
    [self updatePanelHeight];
    [_tableView reloadData];
    [self updatePageLabel];
}

- (void)onValueSnapshot {
    static NSString * const snapshotKey = @"toolbox-memory";
    VMemEngine *engine = [VMemEngine shared];
    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    for (VLToolboxMemItem *item in g_toolboxMemResults) {
        [items addObject:@{@"address": @(item.address), @"type": @(item.dataType)}];
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:VL(@"Snapshot_Title")
                                                                    message:nil
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:VL(@"Snapshot_Save")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        NSUInteger count = [engine captureValueSnapshotForKey:snapshotKey items:items];
        NSString *format = count > 0 ? VL(@"Snapshot_Saved_Fmt") : VL(@"Snapshot_Empty");
        showToast(count > 0 ? [NSString stringWithFormat:format, (unsigned long)count] : format);
    }]];

    UIAlertAction *restore = [UIAlertAction actionWithTitle:VL(@"Snapshot_Restore")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(__unused UIAlertAction *action) {
        NSUInteger count = [engine restoreValueSnapshotForKey:snapshotKey];
        for (VLToolboxMemItem *item in g_toolboxMemResults) {
            NSString *value = [engine readAddress:item.address type:item.dataType];
            if (value) {
                item.currentValue = value;
                if (item.isLocked) item.lockValue = value;
            }
        }
        [self.tableView reloadData];
        NSString *format = count > 0 ? VL(@"Snapshot_Restored_Fmt") : VL(@"Timeline_Restore_Failed");
        showToast(count > 0 ? [NSString stringWithFormat:format, (unsigned long)count] : format);
    }];
    restore.enabled = [engine hasValueSnapshotForKey:snapshotKey];
    [sheet addAction:restore];
    [sheet addAction:[UIAlertAction actionWithTitle:VL(@"Btn_Cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Pagination

- (NSInteger)totalPages {
    NSInteger total = [self fullDataSource].count;
    if (total == 0) return 1;
    return (total + _itemsPerPage - 1) / _itemsPerPage;
}

- (void)prevPage {
    if (_currentPage > 0) {
        _currentPage--;
        [_tableView reloadData];
        [self updatePageLabel];
    }
}

- (void)nextPage {
    if (_currentPage < [self totalPages] - 1) {
        _currentPage++;
        [_tableView reloadData];
        [self updatePageLabel];
    }
}

- (void)updatePageLabel {
    NSInteger total = [self totalPages];
    _pageLabel.text = [NSString stringWithFormat:@"%ld / %ld", (long)(_currentPage + 1), (long)total];
    _prevBtn.enabled = _currentPage > 0;
    _nextBtn.enabled = _currentPage < total - 1;
    _prevBtn.alpha = _prevBtn.enabled ? 1.0 : 0.4;
    _nextBtn.alpha = _nextBtn.enabled ? 1.0 : 0.4;
}

- (void)updatePanelHeight {
    CGFloat sw = self.view.bounds.size.width;
    CGFloat sh = self.view.bounds.size.height;
    CGFloat w = 370;  // 固定宽度
    CGFloat maxH = 370;  // 最大高度
    
    // 固定区域高度: 标题区: 38, Tab: 36, 分页: 36, 按钮: 50, 边距: 20
    CGFloat fixedH = 38 + 36 + 36 + 50 + 20;
    CGFloat rowH = 65; // 估算每行高度
    
    // 计算最大可显示行数 (最多5行)
    CGFloat availableH = maxH - fixedH;
    NSInteger maxRows = (NSInteger)(availableH / rowH);
    if (maxRows < 3) maxRows = 3;
    if (maxRows > 5) maxRows = 5;
    
    // 动态更新 itemsPerPage
    _itemsPerPage = maxRows;
    
    // 计算当前数据量
    NSInteger totalItems = [self fullDataSource].count;
    
    // 如果当前页超出范围，重置到最后一页
    NSInteger totalPages = [self totalPages];
    if (_currentPage >= totalPages && totalPages > 0) {
        _currentPage = totalPages - 1;
    }
    
    // 当前页实际显示的行数
    NSInteger itemCount = MIN(_itemsPerPage, totalItems - _currentPage * _itemsPerPage);
    if (itemCount < 0) itemCount = 0;
    
    // 根据实际数据量计算高度
    CGFloat contentH;
    if (totalItems == 0) {
        contentH = 80; // 空状态最小高度
    } else {
        // 显示实际行数，但不超过 maxRows
        NSInteger displayRows = MIN(totalItems, maxRows);
        contentH = displayRows * rowH;
    }
    
    CGFloat h = fixedH + contentH;
    
    // 限制高度范围
    CGFloat minH = 220;
    h = MAX(minH, MIN(maxH, h));
    
    // 居中显示
    CGRect newFrame = CGRectMake((sw - w) / 2, (sh - h) / 2, w, h);
    
    [UIView animateWithDuration:0.25 animations:^{
        self->_panelView.frame = newFrame;
        
        // 更新内部控件位置
        CGFloat listTop = 74;
        CGFloat listH = h - listTop - 90;
        self->_tableView.frame = CGRectMake(0, listTop, w, listH);
        
        CGFloat pageY = h - 82;
        self->_prevBtn.frame = CGRectMake(12, pageY, 36, 28);
        self->_pageLabel.frame = CGRectMake(54, pageY, w - 108, 28);
        self->_nextBtn.frame = CGRectMake(w - 48, pageY, 36, 28);
        
        CGFloat btnW = 82;
        CGFloat btnSpacing = 8;
        CGFloat totalBtnW = btnW * 3 + btnSpacing * 2;
        CGFloat btnStartX = (w - totalBtnW) / 2;
        self->_importBtn.frame = CGRectMake(btnStartX, h - 42, btnW, 32);
        self->_snapshotBtn.frame = CGRectMake(btnStartX + btnW + btnSpacing, h - 42, btnW, 32);
        self->_refreshBtn.frame = CGRectMake(btnStartX + (btnW + btnSpacing) * 2, h - 42, btnW, 32);
        
        // 更新最小化按钮位置
        UIButton *minBtn = [self->_panelView viewWithTag:101];
        if (minBtn) minBtn.frame = CGRectMake(w - 36, 6, 30, 30);
    }];
}

- (void)onImport {
    // 使用 UIDocumentPickerViewController 选择 vm* 文件
    // iOS 14+ 使用新 API
    NSArray *types = @[@"public.data", @"public.item"];
    UIDocumentPickerViewController *picker;
    
    if (@available(iOS 14.0, *)) {
        // iOS 14+ 使用 UTType
        picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType typeWithIdentifier:@"public.data"]] asCopy:YES];
    } else {
        // iOS 13 及以下使用旧 API
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:types inMode:UIDocumentPickerModeImport];
#pragma clang diagnostic pop
    }
    
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    
    UIViewController *root = GetSafeWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSInteger totalImported = 0;
    
    for (NSURL *url in urls) {
        // 检查文件扩展名
        NSString *ext = url.pathExtension.lowercaseString;
        if (![ext hasPrefix:@"vm"]) {
            continue; // 跳过非 vm* 文件
        }
        
        // 开始访问安全范围资源
        BOOL accessing = [url startAccessingSecurityScopedResource];
        
        NSData *data = [NSData dataWithContentsOfURL:url];
        
        if (accessing) {
            [url stopAccessingSecurityScopedResource];
        }
        
        if (!data) continue;
        
        NSInteger count = [VModParser importVM24Data:data];
        if (count > 0) {
            totalImported += count;
        }
    }
    
    if (totalImported > 0) {
        [_tableView reloadData];
        NSString *msg = [NSString stringWithFormat:VL(@"Msg_Imported"), (long)totalImported];
        showToast(msg);
    } else {
        showToast(VL(@"Msg_ImportFailed"));
    }
}

- (void)close {
    [self hideWithAnimation];
}

- (void)minimize {
    if ([self.view isKindOfClass:[VLToolboxContainerView class]]) {
        [(VLToolboxContainerView *)self.view dockToEdge];
    }
}

- (void)showWithAnimation {
    self.view.hidden = NO;
    if ([self.view isKindOfClass:[VLToolboxContainerView class]]) {
        [(VLToolboxContainerView *)self.view setFocused:YES animated:NO];
    }
    _panelView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    _panelView.alpha = 0;
    
    [self updatePanelHeight];
    [self updatePageLabel];
    
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:0 animations:^{
        self->_panelView.transform = CGAffineTransformIdentity;
        self->_panelView.alpha = 1;
    } completion:nil];
}

- (void)hideWithAnimation {
    [UIView animateWithDuration:0.2 animations:^{
        self->_panelView.transform = CGAffineTransformMakeScale(0.9, 0.9);
        self->_panelView.alpha = 0;
    } completion:^(BOOL finished) {
        self.view.hidden = YES;
        self->_panelView.transform = CGAffineTransformIdentity;
        // 重置位置
        CGFloat sw = self.view.bounds.size.width;
        CGFloat sh = self.view.bounds.size.height;
        self->_panelView.center = CGPointMake(sw / 2, sh / 2);
        // 通知开关同步
        [[NSNotificationCenter defaultCenter] postNotificationName:@"VLWindowDidCloseNotification"
                                                            object:nil
                                                          userInfo:@{@"tag": @1002}];
    }];
}

- (void)onLanguageChanged {
    NSArray *tabs = @[VL(@"Tab_Mem"), VL(@"Tab_Ptr"), VL(@"Tab_RVA"), VL(@"Tab_Sig"), VL(@"Tab_Script")];
    [_tabSeg removeAllSegments];
    for (NSString *t in tabs) {
        [_tabSeg insertSegmentWithTitle:t atIndex:_tabSeg.numberOfSegments animated:NO];
    }
    _tabSeg.selectedSegmentIndex = _currentTab;
    [_refreshBtn setTitle:VL(@"Btn_Refresh") forState:UIControlStateNormal];
    [_importBtn setTitle:VL(@"Btn_Import") forState:UIControlStateNormal];
    [_snapshotBtn setTitle:VL(@"Snapshot_Button") forState:UIControlStateNormal];
    [_tableView reloadData];
}

- (void)onMemResultsReceived:(NSNotification *)notification {
    NSArray *items = notification.userInfo[@"items"];
    if (!items || items.count == 0) return;
    
    [g_toolboxMemResults removeAllObjects];
    for (NSDictionary *dict in items) {
        VLToolboxMemItem *item = [[VLToolboxMemItem alloc] init];
        item.address = [dict[@"address"] unsignedLongLongValue];
        item.dataType = (VMemDataType)[dict[@"dataType"] unsignedIntegerValue];
        item.currentValue = dict[@"currentValue"];
        item.note = @"";
        item.isLocked = NO;
        [g_toolboxMemResults addObject:item];
    }
    
    _tabSeg.selectedSegmentIndex = 0;
    _currentTab = 0;
    [_tableView reloadData];
}

- (void)updateLocks {
    VMemEngine *engine = [VMemEngine shared];
    if (!engine.isReady) return;
    
    for (VLToolboxMemItem *item in g_toolboxMemResults) {
        if (item.isLocked && item.lockValue) {
            [engine writeAddress:item.address value:item.lockValue type:item.dataType];
        }
    }
    
    [[VModEngine shared] updateLocks];
}

#pragma mark - TableView DataSource

- (NSMutableArray *)fullDataSource {
    switch (_currentTab) {
        case 0: return g_toolboxMemResults;
        case 1: return g_ptrItems;
        case 2: return g_rvaItems;
        case 3: return g_sigItems;
        case 4: return (NSMutableArray *)g_scriptItems;
        default: return nil;
    }
}

- (NSMutableArray *)currentDataSource {
    return [self fullDataSource];
}

- (NSArray *)pagedDataSource {
    NSMutableArray *full = [self fullDataSource];
    if (!full || full.count == 0) return @[];
    
    NSInteger start = _currentPage * _itemsPerPage;
    NSInteger end = MIN(start + _itemsPerPage, (NSInteger)full.count);
    
    if (start >= (NSInteger)full.count) return @[];
    
    return [full subarrayWithRange:NSMakeRange(start, end - start)];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self pagedDataSource].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 内存 Tab
    if (_currentTab == 0) {
        return [self memCellForIndexPath:indexPath];
    }
    
    // 脚本 Tab
    if (_currentTab == 4) {
        return [self scriptCellForIndexPath:indexPath];
    }
    
    // 指针/RVA/特征码 Tab
    VModCell *cell = [tableView dequeueReusableCellWithIdentifier:@"VModCell"];
    if (!cell) {
        cell = [[VModCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"VModCell"];
    }
    cell.delegate = self;
    
    NSArray *paged = [self pagedDataSource];
    if (indexPath.row >= (NSInteger)paged.count) return cell;
    
    VModItem *item = paged[indexPath.row];
    NSString *value = nil;
    
    if (item.type == VModTypePointer) {
        value = [[VModEngine shared] readPointerValue:item];
    } else if (item.type == VModTypeSignature) {
        BOOL hasPatchHex = item.sigPatchHex.length > 0 && item.sigOriginalHex.length > 0;
        if (!hasPatchHex) {
            value = [[VModEngine shared] readSignatureValue:item];
        }
    }
    
    [cell configureWithItem:item currentValue:value];
    return cell;
}

- (UITableViewCell *)memCellForIndexPath:(NSIndexPath *)indexPath {
    static NSString *memCellId = @"VLToolboxMemCell";
    UITableViewCell *cell = [_tableView dequeueReusableCellWithIdentifier:memCellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:memCellId];
        cell.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.05];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.layer.cornerRadius = 6;
        cell.textLabel.text = @""; // 不使用系统 textLabel
        cell.textLabel.hidden = YES;

        // 地址标签 (左上)
        UILabel *addrLabel = [[UILabel alloc] init];
        addrLabel.tag = 501;
        addrLabel.textColor = [UIColor cyanColor];
        addrLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:12];
        [cell.contentView addSubview:addrLabel];

        // 值标签 (右上)
        UILabel *valueLabel = [[UILabel alloc] init];
        valueLabel.tag = 502;
        valueLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.9];
        valueLabel.font = [UIFont fontWithName:@"Menlo" size:13];
        valueLabel.textAlignment = NSTextAlignmentRight;
        [cell.contentView addSubview:valueLabel];

        // 类型标签 (左下)
        UILabel *typeLabel = [[UILabel alloc] init];
        typeLabel.tag = 503;
        typeLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.45];
        typeLabel.font = [UIFont fontWithName:@"Menlo" size:10];
        [cell.contentView addSubview:typeLabel];

        // 备注标签 (左下，类型右边)
        UILabel *noteLabel = [[UILabel alloc] init];
        noteLabel.tag = 504;
        noteLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.35];
        noteLabel.font = [UIFont systemFontOfSize:10];
        [cell.contentView addSubview:noteLabel];
    }

    NSArray *paged = [self pagedDataSource];
    if (indexPath.row >= (NSInteger)paged.count) return cell;

    VLToolboxMemItem *item = paged[indexPath.row];
    NSString *currentVal = [[VMemEngine shared] readAddress:item.address type:item.dataType];
    if (currentVal) item.currentValue = currentVal;

    UILabel *addrLabel = [cell.contentView viewWithTag:501];
    UILabel *valueLabel = [cell.contentView viewWithTag:502];
    UILabel *typeLabel = [cell.contentView viewWithTag:503];
    UILabel *noteLabel = [cell.contentView viewWithTag:504];

    CGFloat cw = _tableView.bounds.size.width;

    // 地址 (左上)
    NSString *lockIcon = item.isLocked ? VL(@"UI_Locked") : @"";
    addrLabel.text = [NSString stringWithFormat:@"%@0x%llX", lockIcon, item.address];
    addrLabel.frame = CGRectMake(10, 8, cw * 0.6, 18);

    // 值 (右上)
    valueLabel.text = item.currentValue ?: @"--";
    valueLabel.frame = CGRectMake(cw * 0.5, 8, cw * 0.45, 18);

    // 类型名 (左下)
    static NSArray *typeNames = nil;
    if (!typeNames) {
        typeNames = @[@"i8", @"i16", @"i32", @"i64", @"u8", @"u16", @"u32", @"u64", @"f32", @"f64", @"str", @"iAuto", @"uAuto", @"fAuto"];
    }
    NSString *typeName = item.dataType < typeNames.count ? typeNames[item.dataType] : @"?";
    typeLabel.text = typeName;
    typeLabel.frame = CGRectMake(10, 30, 50, 16);

    // 备注 (左下，类型右边)
    noteLabel.text = item.note.length > 0 ? item.note : @"";
    noteLabel.frame = CGRectMake(62, 30, cw * 0.6, 16);

    cell.backgroundColor = item.isLocked ? [[UIColor cyanColor] colorWithAlphaComponent:0.15] : [[UIColor cyanColor] colorWithAlphaComponent:0.05];

    return cell;
}

// 检测脚本是否使用了 RVA 命令
static BOOL VLScriptUsesRVA(NSString *content) {
    if (!content || content.length == 0) return NO;
    return [content containsString:@"patchRVA"] ||
           [content containsString:@"restoreRVA"] ||
           [content containsString:@"readRVA"];
}

- (UITableViewCell *)scriptCellForIndexPath:(NSIndexPath *)indexPath {
    static NSString *scriptCellId = @"VLToolboxScriptCell";
    UITableViewCell *cell = [_tableView dequeueReusableCellWithIdentifier:scriptCellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:scriptCellId];
        cell.backgroundColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.08];
        cell.textLabel.textColor = [UIColor systemGreenColor];
        cell.textLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:13];
        cell.detailTextLabel.textColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.6];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
        cell.detailTextLabel.numberOfLines = 2;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.layer.cornerRadius = 8;
        
        UIButton *runBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        runBtn.frame = CGRectMake(0, 0, 50, 30);
        [runBtn setTitle:@"▶︎" forState:UIControlStateNormal];
        [runBtn setTitleColor:[UIColor systemGreenColor] forState:UIControlStateNormal];
        runBtn.titleLabel.font = [UIFont systemFontOfSize:18];
        runBtn.tag = 1000;
        cell.accessoryView = runBtn;
        
        // 越狱专属标签
        UILabel *jbBadge = [[UILabel alloc] init];
        jbBadge.tag = 2000;
        jbBadge.font = [UIFont boldSystemFontOfSize:9];
        jbBadge.textColor = [UIColor systemOrangeColor];
        jbBadge.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:0.15];
        jbBadge.textAlignment = NSTextAlignmentCenter;
        jbBadge.layer.cornerRadius = 4;
        jbBadge.clipsToBounds = YES;
        [cell.contentView addSubview:jbBadge];
    }
    
    NSArray *paged = [self pagedDataSource];
    if (indexPath.row >= (NSInteger)paged.count) return cell;
    
    VScriptItem *script = paged[indexPath.row];
    NSString *title = script.note.length > 0 ? script.note : script.fileName;
    if (!title || title.length == 0) title = VL(@"Script_Untitled");
    
    cell.textLabel.text = title;
    NSMutableArray *details = [NSMutableArray array];
    if (script.author.length > 0) [details addObject:[NSString stringWithFormat:@"by %@", script.author]];
    if (script.desc.length > 0) [details addObject:script.desc];
    cell.detailTextLabel.text = [details componentsJoinedByString:@" • "];
    
    // 越狱专属标签 - 检测 RVA 命令
    UILabel *jbBadge = [cell.contentView viewWithTag:2000];
    BOOL usesRVA = VLScriptUsesRVA(script.scriptContent);
    if (usesRVA) {
        jbBadge.text = [NSString stringWithFormat:@" JB | %@ ", VL(@"RVA_Warning")];
        [jbBadge sizeToFit];
        CGFloat cw = _tableView.bounds.size.width;
        jbBadge.frame = CGRectMake(cw - jbBadge.frame.size.width - 60, 6, jbBadge.frame.size.width, 16);
        jbBadge.hidden = NO;
    } else {
        jbBadge.hidden = YES;
    }
    
    // 存储实际索引（分页后的全局索引）
    UIButton *runBtn = (UIButton *)cell.accessoryView;
    runBtn.tag = _currentPage * _itemsPerPage + indexPath.row;
    [runBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [runBtn addTarget:self action:@selector(onRunScript:) forControlEvents:UIControlEventTouchUpInside];
    
    return cell;
}

- (void)onRunScript:(UIButton *)sender {
    NSInteger idx = sender.tag;
    if (idx >= g_scriptItems.count) return;
    
    VScriptItem *script = g_scriptItems[idx];
    if (!script.scriptContent || script.scriptContent.length == 0) {
        showToast(VL(@"Script_Empty"));
        return;
    }
    
    showToast(VL(@"Script_Running"));
    [[VScriptEngine shared] runScript:script.scriptContent completion:^(NSString *log) {
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:script.note ?: @"Script" message:log preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Confirm") style:UIAlertActionStyleDefault handler:nil]];
        [[GetSafeWindow() rootViewController] presentViewController:ac animated:YES completion:nil];
    }];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if ([self fullDataSource].count > 0) return nil;
    
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 80)];
    UILabel *emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, tableView.frame.size.width, 20)];
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    emptyLabel.textColor = [[UIColor lightGrayColor] colorWithAlphaComponent:0.6];
    emptyLabel.font = [UIFont systemFontOfSize:14];
    
    NSArray *emptyTexts = @[VL(@"Empty_Mem"), VL(@"Empty_Ptr"), VL(@"Empty_RVA"), VL(@"Empty_Sig"), VL(@"Empty_Script")];
    emptyLabel.text = emptyTexts[_currentTab];
    [footer addSubview:emptyLabel];
    return footer;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return [self fullDataSource].count > 0 ? 0 : 80;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_currentTab == 0) {
        NSArray *paged = [self pagedDataSource];
        if (indexPath.row >= (NSInteger)paged.count) return;
        VLToolboxMemItem *item = paged[indexPath.row];
        NSInteger actualIndex = _currentPage * _itemsPerPage + indexPath.row;
        [self showMemItemEditor:item atIndex:actualIndex];
    }
}

- (void)showMemItemEditor:(VLToolboxMemItem *)item atIndex:(NSUInteger)index {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"0x%llX", item.address] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Btn_Modify") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self showMemValueEditor:item];
    }]];
    
    NSString *lockTitle = item.isLocked ? VL(@"Msg_Unlocked") : VL(@"Msg_Locked");
    [ac addAction:[UIAlertAction actionWithTitle:lockTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        item.isLocked = !item.isLocked;
        if (item.isLocked) item.lockValue = item.currentValue;
        showToast(item.isLocked ? VL(@"Msg_Locked") : VL(@"Msg_Unlocked"));
        [self->_tableView reloadData];
    }]];
    
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Btn_Delete") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [g_toolboxMemResults removeObjectAtIndex:index];
        [self->_tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
    }]];
    
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    
    if (ac.popoverPresentationController) {
        ac.popoverPresentationController.sourceView = _tableView;
        ac.popoverPresentationController.sourceRect = [_tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
    }
    
    [[GetSafeWindow() rootViewController] presentViewController:ac animated:YES completion:nil];
}

- (void)showMemValueEditor:(VLToolboxMemItem *)item {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"0x%llX", item.address] message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = item.currentValue;
        tf.keyboardType = UIKeyboardTypeDecimalPad;
        tf.placeholder = VL(@"Mem_NewValue");
    }];
    
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Mem_Write") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *newVal = ac.textFields.firstObject.text;
        if (newVal.length > 0) {
            BOOL ok = [[VMemEngine shared] writeAddress:item.address value:newVal type:item.dataType];
            if (ok) {
                item.currentValue = newVal;
                if (item.isLocked) item.lockValue = newVal;
                [self->_tableView reloadData];
                showToast(VL(@"Mem_WriteOK"));
            } else {
                showToast(VL(@"Mem_WriteFail"));
            }
        }
    }]];
    
    [[GetSafeWindow() rootViewController] presentViewController:ac animated:YES completion:nil];
}

#pragma mark - VLModCellDelegate

- (void)cellDidRequestEdit:(VModItem *)item {
    if (item.type == VModTypePointer || item.type == VModTypeRVA || item.type == VModTypeSignature) {
        [VItemEditor showEditorForItem:item fromWindow:GetSafeWindow() delegate:self];
    }
}

- (void)cellDidToggleLock:(VModItem *)item isLocked:(BOOL)locked {
    item.isLocked = locked;
    if (locked) {
        NSString *curr = nil;
        if (item.type == VModTypePointer) {
            curr = [[VModEngine shared] readPointerValue:item];
        } else if (item.type == VModTypeSignature) {
            curr = [[VModEngine shared] readSignatureValue:item];
        }
        if (curr && ![curr containsString:@"("] && ![curr isEqualToString:@"?"]) {
            item.lockValue = curr;
        } else if (!item.lockValue) {
            item.lockValue = @"0";
        }
        showToast(VL(@"Msg_Locked"));
    } else {
        showToast(VL(@"Msg_Unlocked"));
    }
    [VModParser saveConfig];
}

- (void)cellDidToggleEnabled:(VModItem *)item isEnabled:(BOOL)enabled {
    item.isEnabled = enabled;
    showToast(enabled ? VL(@"Msg_Enabled") : VL(@"Msg_Disabled"));
    [VModParser saveConfig];
}

- (void)cellDidToggleRVA:(VModItem *)item {
    [[VModEngine shared] toggleRVA:item];
    [VModParser saveConfig];
    showToast(item.isPatched ? VL(@"Msg_Patched") : VL(@"Msg_Restored"));
}

- (void)cellDidChangeSlider:(VModItem *)item value:(float)value {
    NSString *valStr = [NSString stringWithFormat:@"%.0f", value];
    if (item.type == VModTypePointer) {
        [[VModEngine shared] writePointerValue:item value:valStr];
    } else if (item.type == VModTypeSignature) {
        [[VModEngine shared] writeSignatureValue:item value:valStr];
    }
    item.lockValue = valStr;
    item.isLocked = YES;
    [VModParser saveConfig];
}

- (void)cellDidToggleSwitch:(VModItem *)item isOn:(BOOL)isOn {
    NSString *valStr = isOn ? item.switchOnValue : item.switchOffValue;
    if (item.type == VModTypePointer) {
        [[VModEngine shared] writePointerValue:item value:valStr];
    } else if (item.type == VModTypeSignature) {
        [[VModEngine shared] writeSignatureValue:item value:valStr];
    }
    item.lockValue = valStr;
    item.isLocked = YES;
    [VModParser saveConfig];
}

- (void)cellDidRequestMatch:(VModItem *)item { }

- (void)cellDidClickResultValue:(VModItem *)item atIndex:(NSInteger)index address:(uint64_t)addr currentValue:(NSString *)val { }

- (void)cellDidChangeModeSegment:(VModItem *)item atIndex:(NSInteger)index mode:(VMUIMode)mode {
    if (item.type == VModTypePointer) {
        item.uiMode = mode;
        [VModParser saveConfig];
    }
}

- (void)cellDidChangeResultSlider:(VModItem *)item atIndex:(NSInteger)index value:(NSString *)value { }

- (void)cellDidChangeResultSwitch:(VModItem *)item atIndex:(NSInteger)index isOn:(BOOL)isOn { }

#pragma mark - Swipe to Delete

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 内存 Tab 和脚本 Tab 不支持左滑删除
    if (_currentTab == 0 || _currentTab == 4) return nil;
    
    NSArray *paged = [self pagedDataSource];
    if (indexPath.row >= (NSInteger)paged.count) return nil;
    
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:VL(@"Btn_Delete") handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        NSInteger globalIdx = self->_currentPage * self->_itemsPerPage + indexPath.row;
        NSMutableArray *full = [self fullDataSource];
        if (globalIdx < (NSInteger)full.count) {
            [full removeObjectAtIndex:globalIdx];
            [VModParser saveConfig];
            [self->_tableView reloadData];
            [self updatePageLabel];
        }
        completionHandler(YES);
    }];
    
    deleteAction.backgroundColor = [UIColor colorWithRed:0.8 green:0.1 blue:0.1 alpha:1.0];
    
    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}

#pragma mark - Drag & Drop Reorder

- (NSArray<UIDragItem *> *)tableView:(UITableView *)tableView itemsForBeginningDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath {
    // 内存 Tab 不支持拖动排序
    if (_currentTab == 0) return @[];
    
    NSArray *paged = [self pagedDataSource];
    if (indexPath.row >= (NSInteger)paged.count) return @[];
    
    id item = paged[indexPath.row];
    NSItemProvider *provider = [[NSItemProvider alloc] initWithObject:@""];
    UIDragItem *dragItem = [[UIDragItem alloc] initWithItemProvider:provider];
    dragItem.localObject = item;
    return @[dragItem];
}

- (UITableViewDropProposal *)tableView:(UITableView *)tableView dropSessionDidUpdate:(id<UIDropSession>)session withDestinationIndexPath:(NSIndexPath *)destinationIndexPath {
    if (session.localDragSession) {
        return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationMove intent:UITableViewDropIntentInsertAtDestinationIndexPath];
    }
    return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel];
}

- (void)tableView:(UITableView *)tableView performDropWithCoordinator:(id<UITableViewDropCoordinator>)coordinator {
    if (_currentTab == 0) return;
    
    NSIndexPath *destIndexPath = coordinator.destinationIndexPath;
    if (!destIndexPath) return;
    
    NSMutableArray *fullArray = [self fullDataSource];
    if (!fullArray) return;
    
    for (id<UITableViewDropItem> dropItem in coordinator.items) {
        id item = dropItem.dragItem.localObject;
        if (!item) continue;
        
        // 计算全局源索引
        NSInteger sourceGlobal = [fullArray indexOfObject:item];
        if (sourceGlobal == NSNotFound) continue;
        
        // 计算全局目标索引
        NSInteger destGlobal = _currentPage * _itemsPerPage + destIndexPath.row;
        if (destGlobal > (NSInteger)fullArray.count) destGlobal = fullArray.count;
        
        // 移动数组元素
        [fullArray removeObjectAtIndex:sourceGlobal];
        NSInteger insertIdx = destGlobal;
        if (insertIdx > sourceGlobal) insertIdx--;
        if (insertIdx > (NSInteger)fullArray.count) insertIdx = fullArray.count;
        [fullArray insertObject:item atIndex:insertIdx];
        
        // 重新计算 sortOrder：取前后邻居的中间值
        double prevOrder = 0, nextOrder = 0;
        if (insertIdx > 0) {
            id prevItem = fullArray[insertIdx - 1];
            prevOrder = [prevItem valueForKey:@"sortOrder"] ? [[prevItem valueForKey:@"sortOrder"] doubleValue] : 0;
        }
        if (insertIdx < (NSInteger)fullArray.count - 1) {
            id nextItem = fullArray[insertIdx + 1];
            nextOrder = [nextItem valueForKey:@"sortOrder"] ? [[nextItem valueForKey:@"sortOrder"] doubleValue] : 0;
        }
        
        double newOrder;
        if (insertIdx == 0 && fullArray.count > 1) {
            // 拖到最前面：比第二个小
            newOrder = nextOrder - 1.0;
        } else if (insertIdx == (NSInteger)fullArray.count - 1 && fullArray.count > 1) {
            // 拖到最后面：比倒数第二个大
            newOrder = prevOrder + 1.0;
        } else if (prevOrder > 0 && nextOrder > 0) {
            // 中间：取平均值
            newOrder = (prevOrder + nextOrder) / 2.0;
        } else {
            newOrder = [[NSDate date] timeIntervalSince1970];
        }
        
        [item setValue:@(newOrder) forKey:@"sortOrder"];
        
        [coordinator dropItem:dropItem.dragItem toRowAtIndexPath:destIndexPath];
    }
    
    [VModParser saveConfig];
    [_tableView reloadData];
    [self updatePageLabel];
}

#pragma mark - VLItemEditorDelegate

- (void)editorDidSaveItem:(VModItem *)item {
    [_tableView reloadData];
}

- (void)editorDidDeleteItem:(VModItem *)item {
    [[self currentDataSource] removeObject:item];
    [VModParser saveConfig];
    [_tableView reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (g_toolboxLockTimer) {
        [g_toolboxLockTimer invalidate];
        g_toolboxLockTimer = nil;
    }
}

@end

#pragma mark - VLToolbox

@implementation VLToolbox

+ (void)initialize {
    if (self == [VLToolbox class]) {
        // 注册全局通知，确保工具箱未打开时也能接收锁定通知
        VLToolbox_RegisterGlobalNotifications();
    }
}

+ (void)show {
    UIWindow *w = GetSafeWindow();
    if (!w) return;
    
    VLToolboxImpl *vc = [VLToolboxImpl shared];
    if (vc.view.superview && !vc.view.hidden) return;
    
    if (!vc.view.superview) {
        vc.view.frame = w.bounds;
        [w addSubview:vc.view];
    }
    
    [w bringSubviewToFront:vc.view];
    [vc showWithAnimation];
    [vc.tableView reloadData];
}

+ (void)showMinimized {
    UIWindow *w = GetSafeWindow();
    if (!w) return;
    
    VLToolboxImpl *vc = [VLToolboxImpl shared];
    
    if (!vc.view.superview) {
        vc.view.frame = w.bounds;
        [w addSubview:vc.view];
    }
    
    vc.view.hidden = NO;
    vc.view.backgroundColor = [UIColor clearColor];
    
    // 直接设置为收起状态
    if ([vc.view isKindOfClass:[VLToolboxContainerView class]]) {
        VLToolboxContainerView *container = (VLToolboxContainerView *)vc.view;
        container.contentView.hidden = YES;
        container.isDocked = YES;
        container.isFocused = NO;
        // 直接显示悬浮图标
        [container.dockBadge showInQueueInView:container];
    }
}

+ (void)hide {
    [[VLToolboxImpl shared] hideWithAnimation];
}

+ (void)toggle {
    VLToolboxImpl *vc = [VLToolboxImpl shared];
    if (vc.view.superview && !vc.view.hidden) {
        [self hide];
    } else {
        [self show];
    }
}

+ (BOOL)isVisible {
    VLToolboxImpl *vc = g_toolbox;
    return vc && vc.view.superview && !vc.view.hidden;
}

+ (void)reloadData {
    [[VLToolboxImpl shared].tableView reloadData];
}

@end
