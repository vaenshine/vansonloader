/**
 * VansonLoader L2.7 - VLPanel Internal Header
 * VPanelImpl 的共享内部接口，供各 category 文件使用
 */

#import <UIKit/UIKit.h>
#import "../Engine/VLModEngine.h"
#import "../Engine/VLModParser.h"
#import "../Engine/VLMemEngine.h"
#import "../Engine/VLScriptEngine.h"
#import "../Engine/VLDebugEngine.h"
#import "../Models/VLModItem.h"
#import "../Models/VLScriptItem.h"
#import "../Utils/VLLocalization.h"
#import "../Utils/VLIconManager.h"
#import "VLAbout.h"
#import "VLItemEditor.h"
#import "VLModCell.h"
#import "VLTools.h"
#import "VLMemoryBrowser.h"
#import "VLWatchOverlay.h"
#import "VLFileBrowser.h"
#import "VLFloatingButton.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>

#ifndef VERSION_STRING
#define VERSION_STRING @"unknown"
#endif

// 全局数据
extern NSMutableArray<VModItem *> *g_ptrItems;
extern NSMutableArray<VModItem *> *g_rvaItems;
extern NSMutableArray<VModItem *> *g_sigItems;
extern NSMutableArray<VScriptItem *> *g_scriptItems;

UIWindow *GetSafeWindow(void);
void showToast(NSString *msg);

extern BOOL g_touchPassthroughMode;
extern BOOL g_clickerRunning;
extern NSMutableArray *g_clickPoints;
extern VMemDataType g_currentType;

// 主Tab索引
typedef NS_ENUM(NSInteger, VLMainTab) {
    VLMainTabMemory = 0,
    VLMainTabToolbox,
    VLMainTabTools,
    VLMainTabAbout
};

// 工具箱子Tab索引
typedef NS_ENUM(NSInteger, VLToolboxSubTab) {
    VLToolboxSubLock = 0,
    VLToolboxSubPtr,
    VLToolboxSubRVA,
    VLToolboxSubSig,
    VLToolboxSubScript,
    VLToolboxSubWatch,
    VLToolboxSubBrowser
};

// 面板内部内存结果项
@interface VLPanelMemItem : NSObject
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, assign) VMemDataType dataType;
@property (nonatomic, copy) NSString *currentValue;
@property (nonatomic, assign) BOOL isLocked;
@property (nonatomic, copy) NSString *lockValue;
@end

// 前向声明
@class VPanelImpl;

// 常量
extern VPanelImpl *g_panel;
static const NSInteger kPageSize = 50;

#define BROWSER_PAGE_COUNT 50
#define BROWSER_MAX_BUFFER 500
#define BROWSER_PRELOAD_THRESHOLD 200

static inline UIColor *VLAccentColor(void) {
    return [UIColor colorWithRed:0.18 green:0.96 blue:0.86 alpha:1.0];
}

static inline UIColor *VLSecondaryAccentColor(void) {
    return [UIColor colorWithRed:0.56 green:0.38 blue:1.00 alpha:1.0];
}

static inline UIColor *VLPanelBackgroundColor(void) {
    return [UIColor colorWithRed:0.040 green:0.043 blue:0.060 alpha:0.97];
}

static inline UIColor *VLSurfaceColor(void) {
    return [UIColor colorWithRed:0.075 green:0.080 blue:0.105 alpha:0.92];
}

static inline UIColor *VLStrokeColor(void) {
    return [VLAccentColor() colorWithAlphaComponent:0.22];
}


#pragma mark - VPanelImpl

@interface VPanelImpl : UIView <UITableViewDelegate, UITableViewDataSource,
              UIDocumentPickerDelegate, VLModCellDelegate, VLItemEditorDelegate,
              UITextFieldDelegate, UIScrollViewDelegate>

// 遮罩和面板
@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, strong) UIView *bgView;

// 导航栏
@property (nonatomic, strong) UIView *navBar;
@property (nonatomic, strong) NSArray<UIButton *> *navTabButtons;
@property (nonatomic, strong) NSArray<UIButton *> *sizeButtons;

// 面板体
@property (nonatomic, strong) UIScrollView *panelBody;

// 主Tab页面
@property (nonatomic, strong) UIView *pageMemory;
@property (nonatomic, strong) UIView *pageToolbox;
@property (nonatomic, strong) UIView *pageTools;
@property (nonatomic, strong) UIView *pageAbout;

// 当前状态
@property (nonatomic, assign) VLMainTab currentTab;
@property (nonatomic, assign) NSInteger currentSize;
@property (nonatomic, assign) CGFloat portraitBaseScale;

// 拖动和焦点
@property (nonatomic, assign) BOOL isFocused;
@property (nonatomic, assign) CGPoint dragStartPoint;
@property (nonatomic, assign) CGPoint bgStartCenter;

// ═══ 内存Tab ═══
@property (nonatomic, strong) UISegmentedControl *memModeSeg;
@property (nonatomic, strong) UISegmentedControl *memTypeSeg;
@property (nonatomic, strong) UISegmentedControl *memTypeSeg2;
@property (nonatomic, strong) UISegmentedControl *memFuzzyRow;
@property (nonatomic, strong) UITextField *memValueField;
@property (nonatomic, strong) UIView *memToolbar;
@property (nonatomic, strong) UILabel *memConsoleLabel;
@property (nonatomic, strong) UITextField *nearbyValueField;
@property (nonatomic, strong) UITextField *nearbyRangeField;
@property (nonatomic, strong) UISegmentedControl *nearbyTypeSeg;
@property (nonatomic, strong) UITableView *memResultsTable;
@property (nonatomic, strong) UILabel *memResultsCountLabel;
@property (nonatomic, strong) UILabel *memPageLabel;
@property (nonatomic, strong) UIButton *memSelectButton;
@property (nonatomic, assign) NSInteger memResultPage;
@property (nonatomic, assign) BOOL memIsNextScan;
@property (nonatomic, assign) BOOL memIsFirstSearch;
@property (nonatomic, assign) BOOL memIsSearching;
@property (nonatomic, strong) NSMutableDictionary *memLockedItems;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *multiSelectedAddresses;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *multiSelectedTypes;
@property (nonatomic, assign) BOOL memMultiSelectMode;
@property (nonatomic, assign) BOOL browserMultiSelectMode;

// ═══ 工具箱Tab ═══
@property (nonatomic, strong) NSArray<UIButton *> *tbSubTabButtons;
@property (nonatomic, assign) VLToolboxSubTab currentSubTab;
@property (nonatomic, strong) UITableView *tbTable;
@property (nonatomic, strong) UILabel *tbPageLabel;
@property (nonatomic, assign) NSInteger tbPage;
@property (nonatomic, strong) NSMutableArray *tbMemResults;

// ═══ 工具Tab ═══
@property (nonatomic, strong) UIScrollView *toolsScroll;
@property (nonatomic, strong) UITextField *groupRangeField;
@property (nonatomic, strong) UITextField *floatToleranceField;
@property (nonatomic, strong) UISegmentedControl *groupModeSeg;

// ═══ 关于Tab ═══
@property (nonatomic, strong) UIScrollView *aboutScroll;

// ═══ Watch ═══
@property (nonatomic, strong) NSMutableArray *watchHits;
@property (nonatomic, assign) BOOL watchShowingHits;
@property (nonatomic, assign) NSInteger watchSelectedSlot;
@property (nonatomic, strong) UIView *watchFusionView;
@property (nonatomic, strong) UITableView *watchSlotTable;
@property (nonatomic, strong) UITableView *watchHitTable;

// ═══ Watch Inspector ═══
@property (nonatomic, assign) NSInteger watchNavState;
@property (nonatomic, strong) VLWatchHit *watchInspectHit;
@property (nonatomic, strong) NSArray<NSDictionary *> *watchInspectLines;
@property (nonatomic, strong) UITableView *watchInspectTable;
@property (nonatomic, strong) UIView *watchInspectToolbar;
@property (nonatomic, strong) UIButton *watchBackBtn;

// ═══ 工具箱动态子Tab映射 ═══
@property (nonatomic, strong) NSArray<NSNumber *> *tbSubTabMapping;

// ═══ Browser ═══
@property (nonatomic, strong) UIView *browserFusionView;
@property (nonatomic, strong) UITableView *browserTable;
@property (nonatomic, strong) UITextField *browserAddrField;
@property (nonatomic, strong) UISegmentedControl *browserTypeSeg;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *browserMemoryData;
@property (nonatomic, strong) NSMutableDictionary *browserLockedItems;
@property (nonatomic, assign) uint64_t browserTargetAddr;
@property (nonatomic, assign) uint64_t browserMinAddr;
@property (nonatomic, assign) uint64_t browserMaxAddr;
@property (nonatomic, assign) BOOL browserIsLoading;
@property (nonatomic, assign) BOOL browserIsInitialLoad;
@property (nonatomic, assign) size_t browserTypeSize;
@property (nonatomic, strong) NSTimer *browserLockTimer;
@property (nonatomic, strong) NSTimer *browserRefreshTimer;

// 定时器
@property (nonatomic, strong) NSTimer *lockTimer;
@property (nonatomic, strong) NSTimer *memLockTimer;

// ═══ Tools & About (VLPanel.m 主实现) ═══
- (void)setupToolsPage:(CGFloat)w;
- (void)buildToolsContent:(CGFloat)w;
- (void)setupAboutPage:(CGFloat)w;
- (void)buildAboutContent:(CGFloat)w;

// ═══ UI Helpers (VLPanel.m 主实现) ═══
- (void)styleSegment:(UISegmentedControl *)seg;
- (void)styleSettingField:(UITextField *)field;
- (UIView *)createBox:(NSString *)title x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w;
- (UIButton *)createSmallBtn:(NSString *)title frame:(CGRect)frame;
- (void)addDoneButtonTo:(UITextField *)tf;
- (size_t)sizeForType:(VMDataType)type;
- (NSData *)dataFromValue:(NSString *)value type:(VMDataType)type;

@end

#pragma mark - Nav Category

@interface VPanelImpl (Nav)
- (void)setupNavBar:(CGFloat)w;
- (void)updateNavTabHighlight;
- (void)updateSizeHighlight;
- (void)applySize;
- (void)switchToTab:(VLMainTab)tab animated:(BOOL)animated;
- (void)updateContentSize;
- (void)showWithAnimation;
- (void)hideWithAnimation;
- (void)close;
- (void)setFocused:(BOOL)focused animated:(BOOL)animated;
- (void)resetFusionViews;
@end

#pragma mark - Memory Category

@interface VPanelImpl (Memory)
- (void)setupMemoryPage:(CGFloat)w;
- (void)rebuildMemToolbar;
- (void)updateMemUIForMode;
- (void)refreshMemResults;
- (void)updateMemPager;
- (void)feedbackForSuccess:(BOOL)success;
- (UITableViewCell *)memResultCellForIndex:(NSInteger)row;
- (NSString *)shortNameForType:(VMemDataType)t;
- (void)syncMemoryTypeSegmentsFromGlobalType;
- (NSInteger)nearbyTypeSelectionIndexForCurrentType;
- (void)applyNearbyTypeSelectionIndex:(NSInteger)index syncSegments:(BOOL)syncSegments;
- (void)showWriteValueAlert:(VMemResultItem *)item;
- (void)doMemSearch;
- (void)exitMemoryMultiSelectMode;
- (void)showSelectedBatchActionsForBrowser:(BOOL)isBrowser;
- (void)toggleMemorySelectionAtIndexPath:(NSIndexPath *)indexPath;
@end

#pragma mark - Toolbox Category

@interface VPanelImpl (Toolbox)
- (void)setupToolboxPage:(CGFloat)w;
- (void)rebuildTbBottomButtons;
- (void)updateSubTabHighlight;
- (void)updateTbPager;
- (NSMutableArray *)tbDataSource;
- (void)showWatchFusionView;
- (void)buildWatchFusionView;
- (void)layoutWatchFusion;
- (void)layoutWatchFusionForInspector;
- (void)rebuildWatchInspectToolbar;
- (void)openCodeInspectorForHit:(VLWatchHit *)hit;
- (void)onWatchInspectSelectRow:(NSInteger)row;
- (void)showBrowserFusionView;
- (void)buildBrowserFusionView;
- (void)layoutBrowserFusion;
- (void)browserLoadInitialData;
- (void)browserScrollToTarget;
- (void)browserLoadMoreData:(BOOL)next;
- (void)refreshBrowserRowsFromMemory;
- (void)startBrowserLockTimer;
- (void)startBrowserRefreshTimer;
- (void)stopBrowserRefreshTimer;
- (VMemDataType)browserCurrentType;
- (void)browserUpdateTypeSize;
- (void)navigateBrowserToAddress:(uint64_t)addr;
- (void)exitBrowserMultiSelectMode;
- (void)selectAllVisibleBrowserRows;
- (void)toggleBrowserSelectionAtIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCell *)tbCellForIndex:(NSInteger)row;
- (UITableViewCell *)tbMemCellForItem:(VLPanelMemItem *)item;
- (UITableViewCell *)tbScriptCellForItem:(VScriptItem *)script atIndex:(NSUInteger)idx;
- (UITableViewCell *)watchFusionSlotCellForRow:(NSInteger)row;
- (UITableViewCell *)watchFusionHitCellForRow:(NSInteger)row;
- (UITableViewCell *)browserFusionCellForRow:(NSInteger)row;
- (UITableViewCell *)watchInspectCellForRow:(NSInteger)row;
- (void)showScriptActions:(VScriptItem *)script atIndex:(NSUInteger)idx;
- (void)showTbMemItemActions:(VLPanelMemItem *)item atIndex:(NSUInteger)idx;
@end
