/**
 * VansonLoader L2.3 - Memory Browser & Hex Editor
 * 内存浏览器和 Hex 编辑器实现
 * 支持拖动、缩小、避开灵动岛
 */

#import "VLMemoryBrowser.h"
#import "VLPanelSizeHelper.h"
#import "VLDockBadge.h"
#import "../Engine/VLMemEngine.h"
#import "../Utils/VLLocalization.h"
#import "../Utils/VLIconManager.h"
#import <objc/runtime.h>

UIWindow *GetSafeWindow(void);
void showToast(NSString *msg);

// 触摸穿透模式（在 VLTools.m 中定义）
extern BOOL g_touchPassthroughMode;

static BOOL VLInputLooksHex(NSString *input) {
    NSCharacterSet *hexLetters = [NSCharacterSet characterSetWithCharactersInString:@"abcdefABCDEF"];
    return [input rangeOfCharacterFromSet:hexLetters].location != NSNotFound;
}

static uint64_t VLParseAddressInput(NSString *input) {
    NSString *trimmed = [[(input ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    if (trimmed.length == 0) return 0;

    if ([trimmed.lowercaseString hasPrefix:@"0x"]) {
        return strtoull([trimmed UTF8String], NULL, 16);
    }

    int base = VLInputLooksHex(trimmed) ? 16 : 10;
    return strtoull([trimmed UTF8String], NULL, base);
}

static NSAttributedString *VLBrowserAddressText(uint64_t address, uint64_t targetAddress, UIColor *accent, BOOL emphasized) {
    int64_t offset = (int64_t)address - (int64_t)targetAddress;
    NSString *line1 = [NSString stringWithFormat:@"0x%llX", address];
    NSString *line2 = nil;

    if (offset == 0) {
        line2 = @"BASE | +0x0 | +0";
    } else {
        uint64_t magnitude = (uint64_t)(offset < 0 ? -offset : offset);
        NSString *hexPart = [NSString stringWithFormat:@"%@0x%llX", offset > 0 ? @"+" : @"-", magnitude];
        NSString *decPart = [NSString stringWithFormat:@"%@%lld", offset > 0 ? @"+" : @"-", magnitude];
        line2 = [NSString stringWithFormat:@"%@ | %@", hexPart, decPart];
    }

    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.lineSpacing = 1.0;
    style.lineBreakMode = NSLineBreakByTruncatingMiddle;

    UIColor *primaryColor = emphasized ? [UIColor colorWithWhite:1 alpha:1] : [accent colorWithAlphaComponent:0.8];
    UIColor *secondaryColor = emphasized ? [accent colorWithAlphaComponent:0.9] : [accent colorWithAlphaComponent:0.48];
    UIFont *primaryFont = [UIFont fontWithName:@"Menlo-Bold" size:11];
    UIFont *secondaryFont = [UIFont fontWithName:@"Menlo" size:9];

    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@", line1, line2]];
    [text addAttributes:@{
        NSFontAttributeName: primaryFont,
        NSForegroundColorAttributeName: primaryColor,
        NSParagraphStyleAttributeName: style
    } range:NSMakeRange(0, line1.length)];
    [text addAttributes:@{
        NSFontAttributeName: secondaryFont,
        NSForegroundColorAttributeName: secondaryColor,
        NSParagraphStyleAttributeName: style
    } range:NSMakeRange(line1.length + 1, line2.length)];
    return text;
}

#pragma mark - VLMemBrowserContainerView (触摸穿透+拖动)

@interface VLMemBrowserContainerView : UIView
@property (nonatomic, weak) UIView *contentView;
@property (nonatomic, assign) BOOL isFocused;
@property (nonatomic, assign) CGPoint dragStartPoint;
@property (nonatomic, assign) CGPoint contentStartCenter;
@property (nonatomic, strong) VLDockBadge *dockBadge;
@property (nonatomic, copy) void (^onMinimize)(void);
@property (nonatomic, copy) void (^onRestore)(void);
- (void)setFocused:(BOOL)focused animated:(BOOL)animated;
- (void)minimize;
- (void)restore;
@end

@implementation VLMemBrowserContainerView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _isFocused = YES;
        [self setupDockBadge];
    }
    return self;
}

- (void)setupDockBadge {
    _dockBadge = [[VLDockBadge alloc] initWithImage:IC(@"memory_browser") fallbackIcon:@"🔍"];
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
        if (self.onMinimize) self.onMinimize();
    }];
}

- (void)restore {
    _contentView.hidden = NO;
    [_dockBadge hideAnimated:YES];
    
    [UIView animateWithDuration:0.3 animations:^{
        self.contentView.alpha = 1;
        self.contentView.transform = CGAffineTransformIdentity;
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    } completion:^(BOOL finished) {
        self->_isFocused = YES;
        if (self.onRestore) self.onRestore();
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


#pragma mark - VLMemoryBrowserImpl

// 自动加载参数 (参考 VM 2.5.1)
#define PAGE_COUNT 50
#define MAX_BUFFER_ROWS 500
#define PRELOAD_THRESHOLD 200
#define NUMERIC_REFRESH_INTERVAL 0.5
#define STRING_REFRESH_INTERVAL 1.0

@interface VLMemoryBrowserImpl : NSObject <UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate>
@property (nonatomic, strong) VLMemBrowserContainerView *containerView;
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *addrField;
@property (nonatomic, strong) UISegmentedControl *typeSeg;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *memoryData;
@property (nonatomic, strong) NSMutableDictionary *lockedItems; // 锁定项: addr -> value
@property (nonatomic, strong) NSTimer *lockTimer;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, assign) uint64_t targetAddress;  // 目标地址（用于高亮）
@property (nonatomic, assign) uint64_t minAddr;        // 当前数据最小地址
@property (nonatomic, assign) uint64_t maxAddr;        // 当前数据最大地址
@property (nonatomic, assign) BOOL isLoading;          // 是否正在加载
@property (nonatomic, assign) BOOL isInitialLoad;      // 是否初始加载
@property (nonatomic, assign) size_t typeSize;         // 当前类型字节大小
@property (nonatomic, assign) BOOL isStrMode;          // 字符串浏览模式
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *strDataList; // 字符串结果
@property (nonatomic, assign) uint64_t strMinAddr;     // str扫描范围下界
@property (nonatomic, assign) uint64_t strMaxAddr;     // str扫描范围上界
@end

static VLMemoryBrowserImpl *g_memBrowser = nil;

@implementation VLMemoryBrowserImpl

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_memBrowser = [[VLMemoryBrowserImpl alloc] init];
    });
    return g_memBrowser;
}

- (instancetype)init {
    if (self = [super init]) {
        _memoryData = [NSMutableArray array];
        _strDataList = [NSMutableArray array];
        _lockedItems = [NSMutableDictionary dictionary];
        _targetAddress = 0;
        _minAddr = 0;
        _maxAddr = 0;
        _isLoading = NO;
        _isInitialLoad = YES;
        _isStrMode = NO;
        _typeSize = 4;
    }
    return self;
}

- (void)showInWindow:(UIWindow *)window address:(uint64_t)addr {
    _targetAddress = addr;
    _isInitialLoad = YES;
    [[VLMemEngine shared] initialize];
    
    if (!_containerView) {
        [self setupUI];
    }
    
    // 确保窗口可见
    _containerView.frame = window.bounds;
    _containerView.hidden = NO;
    _panelView.hidden = NO;
    _containerView.alpha = 0;
    [_containerView setFocused:YES animated:NO];
    
    if (!_containerView.superview) {
        [window addSubview:_containerView];
    }
    [window bringSubviewToFront:_containerView];
    
    // 重新加载数据
    [self updateTypeSize];
    [self loadInitialData];
    [self startLockTimer];
    [self startRefreshTimer];
    
    [UIView animateWithDuration:0.25 animations:^{
        self->_containerView.alpha = 1;
    } completion:^(BOOL finished) {
        // 滚动到目标地址并高亮
        [self scrollToTargetAndHighlight];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self->_isInitialLoad = NO;
        });
    }];
}

- (void)showMinimizedInWindow:(UIWindow *)window {
    [[VLMemEngine shared] initialize];
    
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
    [self stopRefreshTimer];
    
    if (!_containerView.superview) {
        [window addSubview:_containerView];
    }
    
    // 直接显示悬浮图标
    [_containerView.dockBadge showInQueueInView:_containerView];
}

- (void)hide {
    [self stopRefreshTimer];
    [UIView animateWithDuration:0.2 animations:^{
        self->_containerView.alpha = 0;
    } completion:^(BOOL finished) {
        self->_containerView.hidden = YES;
        // 重置位置
        CGFloat sw = self->_containerView.bounds.size.width;
        CGFloat sh = self->_containerView.bounds.size.height;
        self->_panelView.center = CGPointMake(sw / 2, sh / 2);
        // 通知开关同步
        [[NSNotificationCenter defaultCenter] postNotificationName:@"VLWindowDidCloseNotification"
                                                            object:nil
                                                          userInfo:@{@"tag": @1003}];
    }];
}

- (BOOL)isVisible {
    return _containerView && _containerView.superview && !_containerView.hidden && !_panelView.hidden;
}

- (void)setupUI {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    _containerView = [[VLMemBrowserContainerView alloc] initWithFrame:screenBounds];
    _containerView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    __weak typeof(self) weakSelf = self;
    _containerView.onMinimize = ^{
        [weakSelf stopRefreshTimer];
    };
    _containerView.onRestore = ^{
        [weakSelf startRefreshTimer];
        [weakSelf refreshVisibleDataSilently];
    };
    
    CGFloat sw = screenBounds.size.width;
    CGFloat sh = screenBounds.size.height;
    CGFloat w = MIN(sw * 0.95, 400);
    CGFloat h = MIN(sh * 0.85, 600);
    
    _panelView = [[UIView alloc] initWithFrame:CGRectMake((sw - w) / 2, (sh - h) / 2, w, h)];
    _panelView.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:0.98];
    _panelView.layer.cornerRadius = 16;
    _panelView.layer.borderWidth = 1.5;
    _panelView.layer.borderColor = [UIColor cyanColor].CGColor;
    [_containerView addSubview:_panelView];
    _containerView.contentView = _panelView;
    
    CGFloat y = 12;
    
    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, y, w - 100, 28)];
    title.text = VL(@"Mem_Browser_Title");
    title.font = [UIFont fontWithName:@"Menlo-Bold" size:16];
    title.textColor = [UIColor cyanColor];
    [_panelView addSubview:title];
    
    // 缩小按钮 (子窗口只保留最小化，关闭由主窗口控制)
    UIButton *minBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    minBtn.frame = CGRectMake(w - 40, 8, 32, 32);
    [minBtn setTitle:@"−" forState:UIControlStateNormal];
    [minBtn setTitleColor:[[UIColor cyanColor] colorWithAlphaComponent:0.6] forState:UIControlStateNormal];
    minBtn.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [minBtn addTarget:self action:@selector(minimize) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:minBtn];
    
    // 大中小缩放按钮
    VLPanelAddSizeButtons(_panelView, screenBounds, w, h);
    
    y += 40;
    
    // 地址输入
    _addrField = [[UITextField alloc] initWithFrame:CGRectMake(12, y, w - 80, 36)];
    _addrField.text = [NSString stringWithFormat:@"0x%llX", _targetAddress];
    _addrField.textColor = [UIColor cyanColor];
    _addrField.font = [UIFont fontWithName:@"Menlo" size:13];
    _addrField.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.5].CGColor;
    _addrField.layer.borderWidth = 1;
    _addrField.layer.cornerRadius = 6;
    _addrField.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.05];
    _addrField.textAlignment = NSTextAlignmentCenter;
    _addrField.inputAccessoryView = [self createKeyboardToolbar:_addrField];
    [_panelView addSubview:_addrField];
    
    UIButton *goBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    goBtn.frame = CGRectMake(w - 60, y, 48, 36);
    [goBtn setTitle:VL(@"Mem_Go") forState:UIControlStateNormal];
    [goBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    goBtn.layer.cornerRadius = 6;
    goBtn.layer.borderWidth = 1;
    goBtn.layer.borderColor = [UIColor cyanColor].CGColor;
    goBtn.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.1];
    [goBtn addTarget:self action:@selector(goToAddress) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:goBtn];
    
    y += 46;
    
    // 类型选择
    NSArray *types = @[@"I32", @"I64", @"F32", @"F64", @"Hex", @"Str"];
    _typeSeg = [[UISegmentedControl alloc] initWithItems:types];
    _typeSeg.frame = CGRectMake(12, y, w - 24, 28);
    _typeSeg.selectedSegmentIndex = 0;
    _typeSeg.selectedSegmentTintColor = [UIColor cyanColor];
    _typeSeg.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.1];
    [_typeSeg setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor cyanColor], NSFontAttributeName: [UIFont systemFontOfSize:11]} forState:UIControlStateNormal];
    [_typeSeg setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blackColor]} forState:UIControlStateSelected];
    [_typeSeg addTarget:self action:@selector(typeChanged) forControlEvents:UIControlEventValueChanged];
    [_panelView addSubview:_typeSeg];
    
    y += 38;
    
    // 内存列表 (移除底部导航按钮，改为自动加载)
    CGFloat tableH = h - y - 12;
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(8, y, w - 16, tableH) style:UITableViewStylePlain];
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 48;
    [_panelView addSubview:_tableView];
}

#pragma mark - Type Size

- (void)updateTypeSize {
    switch (_typeSeg.selectedSegmentIndex) {
        case 0: _typeSize = 4; break;  // I32
        case 1: _typeSize = 8; break;  // I64
        case 2: _typeSize = 4; break;  // F32
        case 3: _typeSize = 8; break;  // F64
        case 5: _typeSize = 1; break;  // Str
        default: _typeSize = 1; break; // Hex
    }
    _isStrMode = (_typeSeg.selectedSegmentIndex == 5);
}

- (VMemDataType)currentType {
    switch (_typeSeg.selectedSegmentIndex) {
        case 0: return VMemDataTypeI32;
        case 1: return VMemDataTypeI64;
        case 2: return VMemDataTypeF32;
        case 3: return VMemDataTypeF64;
        case 5: return VMemDataTypeString;
        default: return VMemDataTypeU8;
    }
}

#pragma mark - Data Loading (参考 VM 2.5.1)

- (void)loadInitialData {
    [_memoryData removeAllObjects];
    
    // 以目标地址为中心，向前后各加载 PAGE_COUNT 行
    _minAddr = _targetAddress - (PAGE_COUNT * _typeSize);
    _maxAddr = _targetAddress + (PAGE_COUNT * _typeSize);
    
    VMemDataType type = [self currentType];
    int totalRows = (int)((_maxAddr - _minAddr) / _typeSize);
    
    for (int i = 0; i <= totalRows; i++) {
        uint64_t addr = _minAddr + (i * _typeSize);
        NSString *val = [[VLMemEngine shared] readAddress:addr type:type];
        [_memoryData addObject:[@{
            @"addr": @(addr),
            @"value": val ?: @"??",
            @"type": @(type)
        } mutableCopy]];
    }
    
    [_tableView reloadData];
    _addrField.text = [NSString stringWithFormat:@"0x%llX", _targetAddress];
}

#define STR_SCAN_RANGE 0x10000
#define STR_MIN_LEN 4
#define STR_MAX_LEN 256

- (void)loadStrData {
    [_strDataList removeAllObjects];
    
    uint64_t scanStart = (_targetAddress > STR_SCAN_RANGE) ? (_targetAddress - STR_SCAN_RANGE) : 0x100000000;
    uint64_t scanEnd = _targetAddress + STR_SCAN_RANGE;
    
    _strMinAddr = scanStart;
    _strMaxAddr = scanEnd;
    
    NSArray *results = [self scanStringsFrom:scanStart to:scanEnd];
    [_strDataList addObjectsFromArray:results];
}

- (void)loadMoreStrData:(BOOL)next {
    if (_isLoading) return;
    _isLoading = YES;
    
    uint64_t rangeSize = STR_SCAN_RANGE;
    uint64_t scanStart, scanEnd;
    
    if (next) {
        scanStart = _strMaxAddr;
        scanEnd = _strMaxAddr + rangeSize;
        _strMaxAddr = scanEnd;
    } else {
        scanEnd = _strMinAddr;
        scanStart = (_strMinAddr > rangeSize) ? (_strMinAddr - rangeSize) : 0x100000000;
        _strMinAddr = scanStart;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *results = [self scanStringsFrom:scanStart to:scanEnd];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (results.count > 0) {
                if (next) {
                    [self->_strDataList addObjectsFromArray:results];
                } else {
                    NSIndexSet *idxSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, results.count)];
                    [self->_strDataList insertObjects:results atIndexes:idxSet];
                    CGFloat addedHeight = results.count * self->_tableView.rowHeight;
                    CGPoint offset = self->_tableView.contentOffset;
                    [CATransaction begin];
                    [CATransaction setDisableActions:YES];
                    [self->_tableView reloadData];
                    [self->_tableView setContentOffset:CGPointMake(offset.x, offset.y + addedHeight) animated:NO];
                    [CATransaction commit];
                    self->_isLoading = NO;
                    return;
                }
                [self->_tableView reloadData];
            }
            self->_isLoading = NO;
        });
    });
}

- (NSArray *)scanStringsFrom:(uint64_t)scanStart to:(uint64_t)scanEnd {
    NSMutableArray *results = [NSMutableArray array];
    VLMemEngine *eng = [VLMemEngine shared];
    
    uint64_t pageSize = 0x4000;
    NSMutableData *fullData = [NSMutableData data];
    uint64_t actualStart = scanEnd;
    
    for (uint64_t addr = scanStart; addr < scanEnd; addr += pageSize) {
        uint64_t chunkLen = MIN(pageSize, scanEnd - addr);
        NSData *chunk = [eng readMemory:addr length:(size_t)chunkLen];
        if (chunk && chunk.length > 0) {
            if (addr < actualStart) actualStart = addr;
            NSUInteger expectedLen = (NSUInteger)(addr - actualStart);
            if (fullData.length < expectedLen) {
                NSUInteger gapSize = expectedLen - fullData.length;
                void *zeros = calloc(1, gapSize);
                [fullData appendBytes:zeros length:gapSize];
                free(zeros);
            }
            [fullData appendData:chunk];
        }
    }
    
    if (fullData.length == 0) return results;
    
    const uint8_t *bytes = (const uint8_t *)fullData.bytes;
    NSUInteger len = fullData.length;
    NSUInteger i = 0;
    
    while (i < len) {
        if ([self isPrintableByte:bytes[i]]) {
            NSUInteger start = i;
            while (i < len && i - start < STR_MAX_LEN && bytes[i] != '\0' && [self isPrintableByte:bytes[i]]) {
                i++;
            }
            NSUInteger strLen = i - start;
            if (strLen >= STR_MIN_LEN) {
                uint64_t addr = actualStart + start;
                NSString *str = [[NSString alloc] initWithBytes:bytes + start length:strLen encoding:NSUTF8StringEncoding];
                if (str) {
                    [results addObject:[@{
                        @"addr": @(addr),
                        @"value": str,
                        @"originalSize": @(strLen)
                    } mutableCopy]];
                }
            }
            if (i < len && bytes[i] == '\0') i++;
        } else {
            i++;
        }
    }
    return results;
}

- (BOOL)isPrintableByte:(uint8_t)b {
    return (b >= 0x20 && b <= 0x7E) || b >= 0xC0;
}

- (void)scrollToTargetAndHighlight {
    NSInteger targetIndex = -1;
    for (NSInteger i = 0; i < _memoryData.count; i++) {
        uint64_t addr = [_memoryData[i][@"addr"] unsignedLongLongValue];
        if (addr == _targetAddress) {
            targetIndex = i;
            break;
        }
    }
    
    if (targetIndex >= 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:targetIndex inSection:0];
        [_tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UITableViewCell *cell = [self->_tableView cellForRowAtIndexPath:indexPath];
            if (cell) {
                UIView *bgView = [[UIView alloc] initWithFrame:cell.bounds];
                bgView.backgroundColor = [[UIColor yellowColor] colorWithAlphaComponent:0.3];
                [cell insertSubview:bgView atIndex:0];
                
                [UIView animateWithDuration:1.0 delay:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
                    bgView.alpha = 0;
                } completion:^(BOOL finished) {
                    [bgView removeFromSuperview];
                }];
            }
        });
    }
}

#pragma mark - UIScrollViewDelegate (自动加载)

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (_isLoading || _isInitialLoad) return;
    
    CGFloat y = scrollView.contentOffset.y;
    CGFloat h = scrollView.frame.size.height;
    CGFloat contentH = scrollView.contentSize.height;
    
    if (_isStrMode) {
        if (y < PRELOAD_THRESHOLD) {
            [self loadMoreStrData:NO];
        } else if (y > contentH - h - PRELOAD_THRESHOLD) {
            [self loadMoreStrData:YES];
        }
        return;
    }
    
    // 接近顶部时向上加载
    if (y < PRELOAD_THRESHOLD) {
        [self loadMoreData:NO];
    }
    // 接近底部时向下加载
    else if (y > contentH - h - PRELOAD_THRESHOLD) {
        [self loadMoreData:YES];
    }
}

- (void)loadMoreData:(BOOL)next {
    if (_isLoading) return;
    _isLoading = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *newRows = [NSMutableArray array];
        VMemDataType type = [self currentType];
        int count = PAGE_COUNT;
        
        if (next) {
            // 向下加载
            for (int i = 1; i <= count; i++) {
                uint64_t addr = self->_maxAddr + (i * self->_typeSize);
                NSString *val = [[VLMemEngine shared] readAddress:addr type:type];
                [newRows addObject:[@{
                    @"addr": @(addr),
                    @"value": val ?: @"??",
                    @"type": @(type)
                } mutableCopy]];
            }
        } else {
            // 向上加载 (倒序生成)
            for (int i = count; i >= 1; i--) {
                uint64_t addr = self->_minAddr - (i * self->_typeSize);
                NSString *val = [[VLMemEngine shared] readAddress:addr type:type];
                [newRows addObject:[@{
                    @"addr": @(addr),
                    @"value": val ?: @"??",
                    @"type": @(type)
                } mutableCopy]];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (newRows.count == 0) {
                self->_isLoading = NO;
                return;
            }
            
            if (next) {
                // 向下加载
                NSInteger startIdx = self->_memoryData.count;
                [self->_memoryData addObjectsFromArray:newRows];
                self->_maxAddr = [newRows.lastObject[@"addr"] unsignedLongLongValue];
                
                NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:newRows.count];
                for (NSInteger i = 0; i < newRows.count; i++) {
                    [indexPaths addObject:[NSIndexPath indexPathForRow:startIdx + i inSection:0]];
                }
                
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                [self->_tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
                [CATransaction commit];
                
                // 限制缓存大小
                if (self->_memoryData.count > MAX_BUFFER_ROWS) {
                    NSInteger removeCount = self->_memoryData.count - MAX_BUFFER_ROWS;
                    [self->_memoryData removeObjectsInRange:NSMakeRange(0, removeCount)];
                    self->_minAddr = [self->_memoryData.firstObject[@"addr"] unsignedLongLongValue];
                    
                    CGFloat removedHeight = removeCount * self->_tableView.rowHeight;
                    CGPoint curr = self->_tableView.contentOffset;
                    CGFloat newY = MAX(0, curr.y - removedHeight);
                    
                    [CATransaction begin];
                    [CATransaction setDisableActions:YES];
                    [self->_tableView reloadData];
                    [self->_tableView setContentOffset:CGPointMake(curr.x, newY) animated:NO];
                    [CATransaction commit];
                }
            } else {
                // 向上加载
                NSIndexSet *idxSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, newRows.count)];
                [self->_memoryData insertObjects:newRows atIndexes:idxSet];
                self->_minAddr = [newRows.firstObject[@"addr"] unsignedLongLongValue];
                
                NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:newRows.count];
                for (NSInteger i = 0; i < newRows.count; i++) {
                    [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                }
                
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                [self->_tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
                [CATransaction commit];
                
                // 限制缓存大小
                if (self->_memoryData.count > MAX_BUFFER_ROWS) {
                    [self->_memoryData removeObjectsInRange:NSMakeRange(MAX_BUFFER_ROWS, self->_memoryData.count - MAX_BUFFER_ROWS)];
                    self->_maxAddr = [self->_memoryData.lastObject[@"addr"] unsignedLongLongValue];
                    [self->_tableView reloadData];
                }
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self->_isLoading = NO;
            });
        });
    });
}

- (UIButton *)createBtn:(NSString *)title frame:(CGRect)frame {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = frame;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    b.layer.cornerRadius = 6;
    b.layer.borderColor = [UIColor cyanColor].CGColor;
    b.layer.borderWidth = 1;
    b.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.08];
    return b;
}

- (void)refreshCurrentData {
    if (_isStrMode) {
        [self loadStrData];
        [_tableView reloadData];
        return;
    }
    VMemDataType type = [self currentType];
    for (NSMutableDictionary *item in _memoryData) {
        uint64_t addr = [item[@"addr"] unsignedLongLongValue];
        NSString *val = [[VLMemEngine shared] readAddress:addr type:type];
        item[@"value"] = val ?: @"??";
    }
    [_tableView reloadData];
}

- (void)startRefreshTimer {
    if (_refreshTimer) return;
    NSTimeInterval interval = _isStrMode ? STRING_REFRESH_INTERVAL : NUMERIC_REFRESH_INTERVAL;
    _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                     target:self
                                                   selector:@selector(refreshVisibleDataSilently)
                                                   userInfo:nil
                                                    repeats:YES];
    if ([_refreshTimer respondsToSelector:@selector(setTolerance:)]) {
        _refreshTimer.tolerance = 0.2;
    }
}

- (void)stopRefreshTimer {
    [_refreshTimer invalidate];
    _refreshTimer = nil;
}

- (void)restartRefreshTimerIfNeeded {
    if (!_refreshTimer) return;
    [self stopRefreshTimer];
    [self startRefreshTimer];
}

- (NSString *)readVisibleStringAtAddress:(uint64_t)address
                                fallback:(NSString *)fallback
                               lengthOut:(NSUInteger *)lengthOut {
    NSUInteger fallbackLen = [fallback lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    NSUInteger readLength = MIN(MAX(fallbackLen + 1, (NSUInteger)64), (NSUInteger)STR_MAX_LEN);
    NSData *data = [[VLMemEngine shared] readMemory:address length:readLength];
    if (data.length == 0) {
        if (lengthOut) *lengthOut = fallbackLen;
        return fallback ?: @"";
    }

    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSUInteger len = 0;
    while (len < data.length && len < STR_MAX_LEN) {
        if (bytes[len] == '\0') break;
        if (![self isPrintableByte:bytes[len]]) break;
        len++;
    }

    if (len == 0) {
        if (lengthOut) *lengthOut = fallbackLen;
        return fallback ?: @"";
    }

    NSString *str = [[NSString alloc] initWithBytes:bytes length:len encoding:NSUTF8StringEncoding];
    if (!str) {
        if (lengthOut) *lengthOut = fallbackLen;
        return fallback ?: @"";
    }

    if (lengthOut) *lengthOut = len;
    return str;
}

- (void)refreshVisibleDataSilently {
    if (!_containerView || _containerView.hidden || _panelView.hidden || !_tableView.window) return;
    if (_isLoading || _isInitialLoad) return;
    if (_tableView.dragging || _tableView.decelerating) return;

    NSArray<NSIndexPath *> *visibleRows = [_tableView indexPathsForVisibleRows];
    if (visibleRows.count == 0) return;

    NSMutableArray<NSIndexPath *> *changedRows = [NSMutableArray array];

    if (_isStrMode) {
        for (NSIndexPath *indexPath in visibleRows) {
            if (indexPath.row >= _strDataList.count) continue;

            NSMutableDictionary *item = _strDataList[indexPath.row];
            NSUInteger oldLen = [item[@"originalSize"] unsignedIntegerValue];
            NSUInteger newLen = oldLen;
            NSString *oldVal = item[@"value"] ?: @"";
            NSString *newVal = [self readVisibleStringAtAddress:[item[@"addr"] unsignedLongLongValue]
                                                       fallback:oldVal
                                                      lengthOut:&newLen];
            NSString *safeNewVal = newVal ?: @"";

            if (oldLen != newLen || ![oldVal isEqualToString:safeNewVal]) {
                item[@"value"] = safeNewVal;
                item[@"originalSize"] = @(newLen);
                [changedRows addObject:indexPath];
            }
        }
    } else {
        VMemDataType type = [self currentType];
        for (NSIndexPath *indexPath in visibleRows) {
            if (indexPath.row >= _memoryData.count) continue;

            NSMutableDictionary *item = _memoryData[indexPath.row];
            uint64_t addr = [item[@"addr"] unsignedLongLongValue];
            NSString *oldVal = item[@"value"] ?: @"";
            NSString *newVal = [[VLMemEngine shared] readAddress:addr type:type] ?: @"??";

            item[@"type"] = @(type);
            if (![oldVal isEqualToString:newVal]) {
                item[@"value"] = newVal;
                [changedRows addObject:indexPath];
            }
        }
    }

    if (changedRows.count == 0) return;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [_tableView reloadRowsAtIndexPaths:changedRows withRowAnimation:UITableViewRowAnimationNone];
    [CATransaction commit];
}

#pragma mark - Actions

- (void)close {
    [self hide];
}

- (void)minimize {
    [self stopRefreshTimer];
    [_containerView minimize];
}

- (void)goToAddress {
    [_addrField resignFirstResponder];
    NSString *addrStr = _addrField.text;
    _targetAddress = VLParseAddressInput(addrStr);
    _isInitialLoad = YES;
    if (_isStrMode) {
        [self loadStrData];
        [_tableView reloadData];
    } else {
        [self loadInitialData];
        [self scrollToTargetAndHighlight];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self->_isInitialLoad = NO;
    });
}

- (void)typeChanged {
    [self updateTypeSize];
    [self restartRefreshTimerIfNeeded];
    _isInitialLoad = YES;
    if (_isStrMode) {
        [self loadStrData];
        [_tableView reloadData];
        if (_strDataList.count > 0) {
            [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
        }
    } else {
        [self loadInitialData];
        [self scrollToTargetAndHighlight];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self->_isInitialLoad = NO;
    });
}

- (void)openHexView {
    [VLHexEditorVC showFromWindow:GetSafeWindow() address:_targetAddress];
}

#pragma mark - Lock

- (void)startLockTimer {
    if (_lockTimer) return;
    _lockTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateLocks) userInfo:nil repeats:YES];
}

- (void)updateLocks {
    VMemEngine *engine = [VMemEngine shared];
    if (!engine.isReady) return;
    
    for (NSNumber *addrKey in _lockedItems) {
        NSDictionary *lockInfo = _lockedItems[addrKey];
        uint64_t addr = [addrKey unsignedLongLongValue];
        NSString *val = lockInfo[@"value"];
        VMemDataType type = (VMemDataType)[lockInfo[@"type"] integerValue];
        [engine writeAddress:addr value:val type:type];
    }
}

- (void)onLockTapped:(UIButton *)sender {
    NSNumber *addrKey = objc_getAssociatedObject(sender, "itemAddr");
    NSNumber *typeNum = objc_getAssociatedObject(sender, "itemType");
    NSString *value = objc_getAssociatedObject(sender, "itemValue");
    if (!addrKey) return;
    
    if (_lockedItems[addrKey]) {
        [_lockedItems removeObjectForKey:addrKey];
        showToast(VL(@"Msg_Unlocked"));
    } else {
        _lockedItems[addrKey] = @{
            @"value": value ?: @"0",
            @"type": typeNum ?: @(VMemDataTypeI32)
        };
        showToast(VL(@"Msg_Locked"));
    }
    
    [_tableView reloadData];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _isStrMode ? _strDataList.count : _memoryData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_isStrMode) {
        static NSString *strCellId = @"StrBrowserCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:strCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:strCellId];
            cell.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.03];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:11];
            cell.textLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.7];
            cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo" size:11];
            cell.detailTextLabel.textColor = [UIColor greenColor];
        }
        NSDictionary *item = _strDataList[indexPath.row];
        uint64_t addr = [item[@"addr"] unsignedLongLongValue];
        NSUInteger origSize = [item[@"originalSize"] unsignedIntegerValue];
        cell.textLabel.text = [NSString stringWithFormat:@"0x%llX [%lu]", addr, (unsigned long)origSize];
        NSString *display = item[@"value"];
        if (display.length > 40) display = [[display substringToIndex:40] stringByAppendingString:@"..."];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"\"%@\"", display];
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }
    
    static NSString *cellId = @"MemBrowserCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.03];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        // 地址标签 (左侧)
        UILabel *addrLabel = [[UILabel alloc] init];
        addrLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.7];
        addrLabel.font = [UIFont fontWithName:@"Menlo" size:11];
        addrLabel.tag = 101;
        addrLabel.numberOfLines = 2;
        addrLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [cell.contentView addSubview:addrLabel];
        
        // 值标签 (中间)
        UILabel *valueLabel = [[UILabel alloc] init];
        valueLabel.textColor = [UIColor cyanColor];
        valueLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:12];
        valueLabel.textAlignment = NSTextAlignmentRight;
        valueLabel.tag = 102;
        [cell.contentView addSubview:valueLabel];
        
        // 锁定按钮 (右侧，在数值后面)
        UIButton *lockBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        lockBtn.titleLabel.font = [UIFont systemFontOfSize:11];
        lockBtn.tag = 103;
        [cell.contentView addSubview:lockBtn];
    }
    
    NSDictionary *item = _memoryData[indexPath.row];
    uint64_t addr = [item[@"addr"] unsignedLongLongValue];
    NSNumber *addrKey = @(addr);
    BOOL isLocked = _lockedItems[addrKey] != nil;
    BOOL isTarget = (addr == _targetAddress);
    
    UILabel *addrLabel = [cell.contentView viewWithTag:101];
    UILabel *valueLabel = [cell.contentView viewWithTag:102];
    UIButton *lockBtn = [cell.contentView viewWithTag:103];
    
    // 布局: 地址 | 数值 | 锁定按钮
    CGFloat cellW = tableView.bounds.size.width;
    CGFloat lockBtnW = 50;
    CGFloat addrW = MIN(158.0, MAX(126.0, cellW * 0.46));
    CGFloat valueW = MAX(72.0, cellW - addrW - lockBtnW - 24);
    
    addrLabel.frame = CGRectMake(8, 2, addrW, tableView.rowHeight - 4);
    valueLabel.frame = CGRectMake(addrW + 10, 0, valueW - 2, tableView.rowHeight);
    lockBtn.frame = CGRectMake(cellW - lockBtnW - 8, 9, lockBtnW, 30);
    
    addrLabel.attributedText = VLBrowserAddressText(addr, _targetAddress, [UIColor cyanColor], isTarget);
    valueLabel.text = item[@"value"];
    
    // 目标地址高亮
    if (isTarget) {
        cell.backgroundColor = [[UIColor yellowColor] colorWithAlphaComponent:0.15];
        addrLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:11];
        valueLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:12];
    } else if (isLocked) {
        cell.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.12];
        addrLabel.font = [UIFont fontWithName:@"Menlo" size:11];
        valueLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:12];
    } else {
        cell.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.03];
        addrLabel.font = [UIFont fontWithName:@"Menlo" size:11];
        valueLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:12];
    }
    
    // 锁定状态
    [lockBtn setTitle:isLocked ? VL(@"UI_Locked") : VL(@"UI_Unlocked") forState:UIControlStateNormal];
    [lockBtn setTitleColor:isLocked ? [UIColor cyanColor] : [[UIColor cyanColor] colorWithAlphaComponent:0.5] forState:UIControlStateNormal];
    
    // 存储地址和类型
    objc_setAssociatedObject(lockBtn, "itemAddr", addrKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(lockBtn, "itemType", item[@"type"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(lockBtn, "itemValue", item[@"value"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [lockBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [lockBtn addTarget:self action:@selector(onLockTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (_isStrMode) {
        NSMutableDictionary *item = _strDataList[indexPath.row];
        [self showStrEditAlert:item indexPath:indexPath];
        return;
    }
    
    NSDictionary *item = _memoryData[indexPath.row];
    uint64_t addr = [item[@"addr"] unsignedLongLongValue];
    VMemDataType type = [self currentType];
    
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"0x%llX", addr]
                                                                message:nil
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = item[@"value"];
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    VLMemWriteUndoItem *undo = [[VLMemEngine shared] lastManualWriteUndoForAddress:addr type:type];
    if (undo) {
        NSString *undoTitle = [NSString stringWithFormat:@"%@: %@", VL(@"Undo_Last_Modify"), undo.oldValue ?: @""];
        [ac addAction:[UIAlertAction actionWithTitle:undoTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            BOOL ok = [[VLMemEngine shared] undoLastManualWriteForAddress:addr type:type];
            if (ok) {
                [self refreshCurrentData];
                showToast(VL(@"Undo_Success"));
            } else {
                showToast(VL(@"Undo_Failed"));
            }
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Mem_Write") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *newVal = ac.textFields.firstObject.text;
        if (newVal.length > 0) {
            NSString *oldVal = [[VLMemEngine shared] readAddress:addr type:type];
            NSData *oldData = [[VLMemEngine shared] readMemory:addr length:[self writeSizeForType:type oldValue:oldVal newValue:newVal]];
            [[VLMemEngine shared] rememberManualWriteUndoAtAddress:addr
                                                             type:type
                                                         oldValue:oldVal
                                                          oldData:oldData
                                                         newValue:newVal];
            [[VLMemEngine shared] writeAddress:addr value:newVal type:type];
            [self refreshCurrentData];
            showToast(VL(@"Mem_WriteOK"));
        }
    }]];
    
    UIViewController *root = GetSafeWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:ac animated:YES completion:nil];
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

- (void)showStrEditAlert:(NSMutableDictionary *)item indexPath:(NSIndexPath *)indexPath {
    uint64_t addr = [item[@"addr"] unsignedLongLongValue];
    NSUInteger origSize = [item[@"originalSize"] unsignedIntegerValue];
    NSString *msg = [NSString stringWithFormat:@"0x%llX\n%@ %lu", addr, VL(@"Browser_Str_OrigLen"), (unsigned long)origSize];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:VL(@"Browser_Str_Edit") message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = item[@"value"];
        tf.keyboardType = UIKeyboardTypeDefault;
        tf.clearButtonMode = UITextFieldViewModeAlways;
    }];
    
    __weak typeof(self) weakSelf = self;
    VLMemWriteUndoItem *undo = [[VLMemEngine shared] lastManualWriteUndoForAddress:addr type:VMemDataTypeString];
    if (undo) {
        NSString *undoTitle = [NSString stringWithFormat:@"%@: %@", VL(@"Undo_Last_Modify"), undo.oldValue ?: @""];
        [alert addAction:[UIAlertAction actionWithTitle:undoTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            BOOL ok = [[VLMemEngine shared] undoLastManualWriteForAddress:addr type:VMemDataTypeString];
            if (ok) {
                item[@"value"] = undo.oldValue ?: @"";
                [weakSelf refreshCurrentData];
                showToast(VL(@"Undo_Success"));
            } else {
                showToast(VL(@"Undo_Failed"));
            }
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *newVal = alert.textFields.firstObject.text ?: @"";
        NSUInteger newLen = [newVal lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        
        if (newLen > origSize) {
            NSString *warnMsg = [NSString stringWithFormat:VL(@"Browser_Str_Overflow_Msg"), (unsigned long)origSize, (unsigned long)newLen];
            UIAlertController *warn = [UIAlertController alertControllerWithTitle:VL(@"Browser_Str_Overflow") message:warnMsg preferredStyle:UIAlertControllerStyleAlert];
            [warn addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
            [warn addAction:[UIAlertAction actionWithTitle:VL(@"Browser_Str_Force_Write") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a2) {
                [weakSelf writeStr:newVal toItem:item indexPath:indexPath];
            }]];
            UIViewController *root = GetSafeWindow().rootViewController;
            while (root.presentedViewController) root = root.presentedViewController;
            [root presentViewController:warn animated:YES completion:nil];
        } else {
            [weakSelf writeStr:newVal toItem:item indexPath:indexPath];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    
    UIViewController *root = GetSafeWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:alert animated:YES completion:nil];
}

- (void)writeStr:(NSString *)newVal toItem:(NSMutableDictionary *)item indexPath:(NSIndexPath *)indexPath {
    uint64_t addr = [item[@"addr"] unsignedLongLongValue];
    const char *cstr = [newVal UTF8String];
    NSUInteger writeLen = strlen(cstr) + 1;
    NSString *oldVal = item[@"value"] ?: @"";
    NSUInteger oldSize = MAX([[oldVal dataUsingEncoding:NSUTF8StringEncoding] length] + 1, writeLen);
    NSData *oldData = [[VLMemEngine shared] readMemory:addr length:oldSize];
    [[VLMemEngine shared] rememberManualWriteUndoAtAddress:addr
                                                     type:VMemDataTypeString
                                                 oldValue:oldVal
                                                  oldData:oldData
                                                 newValue:newVal];
    NSData *data = [NSData dataWithBytes:cstr length:writeLen];
    [[VLMemEngine shared] writeMemory:addr data:data];
    
    item[@"value"] = newVal;
    item[@"originalSize"] = @(writeLen - 1);
    [_tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    showToast(VL(@"Mem_WriteOK"));
}

- (UIToolbar *)createKeyboardToolbar:(UITextField *)tf {
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 280, 44)];
    toolbar.barStyle = UIBarStyleBlack;
    toolbar.tintColor = [UIColor cyanColor];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:VL(@"Btn_Done") style:UIBarButtonItemStyleDone target:tf action:@selector(resignFirstResponder)];
    toolbar.items = @[flex, done];
    return toolbar;
}

@end

#pragma mark - VLMemoryBrowserVC

@implementation VLMemoryBrowserVC

+ (void)showFromWindow:(UIWindow *)window address:(uint64_t)addr {
    [[VLMemoryBrowserImpl shared] showInWindow:window address:addr];
}

+ (void)showWithAddress:(uint64_t)addr {
    UIWindow *w = GetSafeWindow();
    if (!w) return;
    // 确保窗口弹出并显示
    [[VLMemoryBrowserImpl shared] showInWindow:w address:addr];
}

+ (void)showMinimized {
    UIWindow *w = GetSafeWindow();
    if (!w) return;
    [[VLMemoryBrowserImpl shared] showMinimizedInWindow:w];
}

+ (void)hide {
    [[VLMemoryBrowserImpl shared] hide];
}

+ (void)toggle {
    VLMemoryBrowserImpl *impl = [VLMemoryBrowserImpl shared];
    if ([impl isVisible]) {
        [impl hide];
    } else {
        [impl showInWindow:GetSafeWindow() address:impl.targetAddress];
    }
}

+ (BOOL)isVisible {
    return [[VLMemoryBrowserImpl shared] isVisible];
}

@end



#pragma mark - VLHexEditorImpl

@interface VLHexEditorImpl : NSObject
@property (nonatomic, strong) VLMemBrowserContainerView *containerView;
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UITextView *hexView;
@property (nonatomic, strong) UITextField *addrField;
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, assign) NSUInteger bytesPerPage;
@end

static VLHexEditorImpl *g_hexEditor = nil;

@implementation VLHexEditorImpl

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_hexEditor = [[VLHexEditorImpl alloc] init];
    });
    return g_hexEditor;
}

- (instancetype)init {
    if (self = [super init]) {
        _bytesPerPage = 256;
        _address = 0;
    }
    return self;
}

- (void)showInWindow:(UIWindow *)window address:(uint64_t)addr {
    _address = addr;
    [[VLMemEngine shared] initialize];
    
    if (_containerView.superview && !_containerView.hidden) {
        [self loadHex];
        return;
    }
    
    if (!_containerView) {
        [self setupUI];
    }
    
    _containerView.frame = window.bounds;
    _containerView.hidden = NO;
    _containerView.alpha = 0;
    
    if (!_containerView.superview) {
        [window addSubview:_containerView];
    }
    [window bringSubviewToFront:_containerView];
    
    [self loadHex];
    
    [UIView animateWithDuration:0.25 animations:^{
        self->_containerView.alpha = 1;
    }];
}

- (void)hide {
    [UIView animateWithDuration:0.2 animations:^{
        self->_containerView.alpha = 0;
    } completion:^(BOOL finished) {
        self->_containerView.hidden = YES;
        CGFloat sw = self->_containerView.bounds.size.width;
        CGFloat sh = self->_containerView.bounds.size.height;
        self->_panelView.center = CGPointMake(sw / 2, sh / 2);
    }];
}

- (BOOL)isVisible {
    return _containerView && _containerView.superview && !_containerView.hidden && !_panelView.hidden;
}

- (void)setupUI {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    _containerView = [[VLMemBrowserContainerView alloc] initWithFrame:screenBounds];
    _containerView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    _containerView.dockBadge.iconImage = IC(@"memory_browser");
    if (!_containerView.dockBadge.iconImage) {
        _containerView.dockBadge.icon = @"📝";
    }
    
    CGFloat sw = screenBounds.size.width;
    CGFloat sh = screenBounds.size.height;
    CGFloat w = MIN(sw * 0.95, 400);
    CGFloat h = MIN(sh * 0.85, 600);
    
    _panelView = [[UIView alloc] initWithFrame:CGRectMake((sw - w) / 2, (sh - h) / 2, w, h)];
    _panelView.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:0.98];
    _panelView.layer.cornerRadius = 16;
    _panelView.layer.borderWidth = 1.5;
    _panelView.layer.borderColor = [UIColor cyanColor].CGColor;
    [_containerView addSubview:_panelView];
    _containerView.contentView = _panelView;
    
    CGFloat y = 12;
    
    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, y, w - 100, 28)];
    title.text = VL(@"Mem_Hex_Title");
    title.font = [UIFont fontWithName:@"Menlo-Bold" size:16];
    title.textColor = [UIColor cyanColor];
    [_panelView addSubview:title];
    
    // 缩小按钮 (子窗口只保留最小化，关闭由主窗口控制)
    UIButton *minBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    minBtn.frame = CGRectMake(w - 40, 8, 32, 32);
    [minBtn setTitle:@"−" forState:UIControlStateNormal];
    [minBtn setTitleColor:[[UIColor cyanColor] colorWithAlphaComponent:0.6] forState:UIControlStateNormal];
    minBtn.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [minBtn addTarget:self action:@selector(minimize) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:minBtn];
    
    // 大中小缩放按钮
    VLPanelAddSizeButtons(_panelView, screenBounds, w, h);
    
    y += 40;
    
    // 地址输入
    _addrField = [[UITextField alloc] initWithFrame:CGRectMake(12, y, w - 80, 36)];
    _addrField.text = [NSString stringWithFormat:@"0x%llX", _address];
    _addrField.textColor = [UIColor cyanColor];
    _addrField.font = [UIFont fontWithName:@"Menlo" size:13];
    _addrField.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.5].CGColor;
    _addrField.layer.borderWidth = 1;
    _addrField.layer.cornerRadius = 6;
    _addrField.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.05];
    _addrField.textAlignment = NSTextAlignmentCenter;
    _addrField.inputAccessoryView = [self createKeyboardToolbar:_addrField];
    [_panelView addSubview:_addrField];
    
    UIButton *goBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    goBtn.frame = CGRectMake(w - 60, y, 48, 36);
    [goBtn setTitle:VL(@"Mem_Go") forState:UIControlStateNormal];
    [goBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    goBtn.layer.cornerRadius = 6;
    goBtn.layer.borderWidth = 1;
    goBtn.layer.borderColor = [UIColor cyanColor].CGColor;
    goBtn.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.1];
    [goBtn addTarget:self action:@selector(goToAddress) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:goBtn];
    
    y += 46;
    
    // Hex 显示区域
    CGFloat hexH = h - y - 60;
    _hexView = [[UITextView alloc] initWithFrame:CGRectMake(12, y, w - 24, hexH)];
    _hexView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    _hexView.textColor = [UIColor cyanColor];
    _hexView.font = [UIFont fontWithName:@"Menlo" size:10];
    _hexView.editable = NO;
    _hexView.layer.cornerRadius = 8;
    _hexView.layer.borderWidth = 1;
    _hexView.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.3].CGColor;
    [_panelView addSubview:_hexView];
    
    y += hexH + 8;
    
    // 导航按钮
    CGFloat btnW = (w - 36) / 3;
    
    UIButton *prevBtn = [self createBtn:[NSString stringWithFormat:@"◀ %@", VL(@"Mem_PrevPage")] frame:CGRectMake(12, y, btnW, 32)];
    [prevBtn addTarget:self action:@selector(prevPage) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:prevBtn];
    
    UIButton *copyBtn = [self createBtn:VL(@"Mem_Copy") frame:CGRectMake(18 + btnW, y, btnW, 32)];
    [copyBtn addTarget:self action:@selector(copyHex) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:copyBtn];
    
    UIButton *nextBtn = [self createBtn:[NSString stringWithFormat:@"%@ ▶", VL(@"Mem_NextPage")] frame:CGRectMake(24 + btnW * 2, y, btnW, 32)];
    [nextBtn addTarget:self action:@selector(nextPage) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:nextBtn];
}

- (UIButton *)createBtn:(NSString *)title frame:(CGRect)frame {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = frame;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    b.layer.cornerRadius = 6;
    b.layer.borderColor = [UIColor cyanColor].CGColor;
    b.layer.borderWidth = 1;
    b.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.08];
    return b;
}

- (void)loadHex {
    NSData *data = [[VLMemEngine shared] readMemory:_address length:_bytesPerPage];
    if (!data) {
        _hexView.text = VL(@"Mem_ReadFailed");
        return;
    }
    
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSMutableString *hexStr = [NSMutableString string];
    
    for (NSUInteger i = 0; i < data.length; i += 16) {
        [hexStr appendFormat:@"%08llX  ", _address + i];
        
        for (NSUInteger j = 0; j < 16; j++) {
            if (i + j < data.length) {
                [hexStr appendFormat:@"%02X ", bytes[i + j]];
            } else {
                [hexStr appendString:@"   "];
            }
            if (j == 7) [hexStr appendString:@" "];
        }
        
        [hexStr appendString:@" |"];
        for (NSUInteger j = 0; j < 16 && i + j < data.length; j++) {
            uint8_t c = bytes[i + j];
            [hexStr appendFormat:@"%c", (c >= 32 && c < 127) ? c : '.'];
        }
        [hexStr appendString:@"|\n"];
    }
    
    _hexView.text = hexStr;
    _addrField.text = [NSString stringWithFormat:@"0x%llX", _address];
}

#pragma mark - Actions

- (void)close {
    [self hide];
}

- (void)minimize {
    [_containerView minimize];
}

- (void)goToAddress {
    [_addrField resignFirstResponder];
    NSString *addrStr = _addrField.text;
    _address = VLParseAddressInput(addrStr);
    [self loadHex];
}

- (void)prevPage {
    if (_address >= _bytesPerPage) {
        _address -= _bytesPerPage;
    } else {
        _address = 0;
    }
    [self loadHex];
}

- (void)nextPage {
    _address += _bytesPerPage;
    [self loadHex];
}

- (void)copyHex {
    [UIPasteboard generalPasteboard].string = _hexView.text;
    showToast(VL(@"Mem_Copied"));
}

- (UIToolbar *)createKeyboardToolbar:(UITextField *)tf {
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 280, 44)];
    toolbar.barStyle = UIBarStyleBlack;
    toolbar.tintColor = [UIColor cyanColor];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:VL(@"Btn_Done") style:UIBarButtonItemStyleDone target:tf action:@selector(resignFirstResponder)];
    toolbar.items = @[flex, done];
    return toolbar;
}

@end


#pragma mark - VLHexEditorVC

@implementation VLHexEditorVC

+ (void)showFromWindow:(UIWindow *)window address:(uint64_t)addr {
    [[VLHexEditorImpl shared] showInWindow:window address:addr];
}

+ (void)hide {
    [[VLHexEditorImpl shared] hide];
}

+ (void)toggle {
    VLHexEditorImpl *impl = [VLHexEditorImpl shared];
    if ([impl isVisible]) {
        [impl hide];
    } else {
        [impl showInWindow:GetSafeWindow() address:impl.address];
    }
}

+ (BOOL)isVisible {
    return [[VLHexEditorImpl shared] isVisible];
}

@end
