/**
 * VansonLoader L2.7 - VLPanel 统一面板 (协调器)
 * init/dealloc, setupPanel, Tools/About页面, TableView delegate分发,
 * VModCellDelegate, 通知, 定时器, UI helpers, 公共API
 *
 * 各 category 文件:
 *   VLPanelNav.m     — 导航栏、Tab切换、拖动焦点、显示隐藏、屏幕旋转
 *   VLPanelMemory.m  — 内存搜索Tab UI、搜索逻辑、结果Cell、批量操作
 *   VLPanelToolbox.m — 工具箱Tab、Watch/Browser Fusion、Cell、脚本操作
 */

#import "VLPanel+Internal.h"
#import "VLPanelSizeHelper.h"

// ═══ 全局实例 & 常量 ═══
VPanelImpl *g_panel = nil;

// ═══ VLPanelMemItem 实现 ═══
@implementation VLPanelMemItem
@end

#pragma mark - VPanelImpl 主实现

@implementation VPanelImpl

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.isFocused = YES;
        self.currentTab = VLMainTabMemory;
        self.currentSize = 2;
        self.memResultPage = 0;
        self.tbPage = 0;
        self.currentSubTab = VLToolboxSubBrowser;
        self.memIsNextScan = NO;
        self.memIsFirstSearch = YES;
        self.memIsSearching = NO;
        self.memLockedItems = [NSMutableDictionary dictionary];
        self.multiSelectedAddresses = [NSMutableSet set];
        self.multiSelectedTypes = [NSMutableDictionary dictionary];
        self.memMultiSelectMode = NO;
        self.browserMultiSelectMode = NO;
        self.tbMemResults = [NSMutableArray array];
        self.watchHits = [NSMutableArray array];
        self.watchShowingHits = NO;
        self.watchSelectedSlot = -1;
        self.watchNavState = 0;
        self.watchInspectHit = nil;
        self.watchInspectLines = nil;

        self.browserMemoryData = [NSMutableArray array];
        self.browserLockedItems = [NSMutableDictionary dictionary];
        self.browserTargetAddr = 0x100000000ULL;
        self.browserMinAddr = 0;
        self.browserMaxAddr = 0;
        self.browserIsLoading = NO;
        self.browserIsInitialLoad = YES;
        self.browserTypeSize = 4;

        if (!g_currentType) g_currentType = VMemDataTypeI32;

        [[VMemEngine shared] initialize];
        [self setupPanel];

        self.lockTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                         target:[VModEngine shared]
                                       selector:@selector(updateLocks)
                                       userInfo:nil repeats:YES];

        self.memLockTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                         target:self
                                       selector:@selector(updateMemLocks)
                                       userInfo:nil repeats:YES];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLanguageChanged) name:@"VansonLanguageChanged" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMemResultsReceived:) name:@"VMemResultsToPanel" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMemItemLocked:) name:@"VMemItemLockedToPanel" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMemItemUnlocked:) name:@"VMemItemUnlockedFromPanel" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onWatchHitReceived:) name:@"VLWatchHitReceived" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onOrientationChanged) name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_lockTimer invalidate];
    [_memLockTimer invalidate];
    [_browserLockTimer invalidate];
    [_browserRefreshTimer invalidate];
}

#pragma mark - Panel Setup

- (void)setupPanel {
    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    CGFloat sh = [UIScreen mainScreen].bounds.size.height;
    CGFloat longSide = MAX(sw, sh);
    CGFloat shortSide = MIN(sw, sh);
    CGFloat w = MIN(longSide * 0.94, 560);
    CGFloat maxH = shortSide * 0.85;

    if (sw < sh) {
        _portraitBaseScale = (sw * 0.94) / w;
        if (_portraitBaseScale > 1.0) _portraitBaseScale = 1.0;
    } else {
        _portraitBaseScale = 1.0;
    }

    _dimView = [[UIView alloc] initWithFrame:self.bounds];
    _dimView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.38];
    _dimView.alpha = 0;
    UITapGestureRecognizer *dimTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDimTap)];
    [_dimView addGestureRecognizer:dimTap];
    [self addSubview:_dimView];

    _bgView = [[UIView alloc] initWithFrame:CGRectMake((sw - w) / 2, (sh - maxH) / 2, w, maxH)];
    _bgView.backgroundColor = VLPanelBackgroundColor();
    _bgView.layer.cornerRadius = 18;
    _bgView.layer.borderWidth = 1.5;
    _bgView.layer.borderColor = VLStrokeColor().CGColor;
    _bgView.layer.shadowColor = VLAccentColor().CGColor;
    _bgView.layer.shadowOffset = CGSizeZero;
    _bgView.layer.shadowRadius = 28;
    _bgView.layer.shadowOpacity = 0.24;
    _bgView.clipsToBounds = YES;
    [self addSubview:_bgView];

    [self setupNavBar:w];

    CGFloat bodyTop = 44;
    _panelBody = [[UIScrollView alloc] initWithFrame:CGRectMake(0, bodyTop, w, maxH - bodyTop)];
    _panelBody.showsVerticalScrollIndicator = NO;
    _panelBody.showsHorizontalScrollIndicator = NO;
    _panelBody.bounces = YES;
    [_bgView addSubview:_panelBody];

    [self setupMemoryPage:w];
    [self setupToolboxPage:w];
    [self setupToolsPage:w];
    [self setupAboutPage:w];
    [self switchToTab:VLMainTabMemory animated:NO];
}

#pragma mark - Tools Page

- (void)setupToolsPage:(CGFloat)w {
    CGFloat bodyH = _panelBody.frame.size.height;
    _pageTools = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, bodyH)];
    _pageTools.hidden = YES;
    [_panelBody addSubview:_pageTools];

    _toolsScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, bodyH)];
    _toolsScroll.showsVerticalScrollIndicator = NO;
    [_pageTools addSubview:_toolsScroll];

    [self buildToolsContent:w];
}

- (void)buildToolsContent:(CGFloat)w {
    for (UIView *v in _toolsScroll.subviews) [v removeFromSuperview];

    CGFloat bodyH = _panelBody.frame.size.height;
    CGFloat pad = 12; CGFloat colW = w - pad * 2; CGFloat gap = 10; CGFloat btnH = 28;
    CGFloat usable = bodyH - pad * 2 - gap * 2;
    CGFloat clickH = MAX(100, usable * 0.44);
    CGFloat rowH = MAX(66, usable * 0.28);
    CGFloat y = pad;
    CGFloat titleH = 22; CGFloat innerPad = 10; CGFloat rowGap = 10;
    CGFloat row1Y = titleH + innerPad; CGFloat row2Y = row1Y + btnH + rowGap;

    // ═══ 连点器 ═══
    UIView *clickBox = [self createBox:VL(@"Tool_Clicker") x:pad y:y w:colW];
    clickBox.frame = CGRectMake(pad, y, colW, clickH);

    CGFloat cx = innerPad;
    UILabel *freqLabel = [[UILabel alloc] initWithFrame:CGRectMake(cx, row1Y, 40, btnH)];
    freqLabel.text = VL(@"Click_Freq");
    freqLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.5];
    freqLabel.font = [UIFont systemFontOfSize:10];
    [clickBox addSubview:freqLabel]; cx += 40;

    UIButton *minusBtn = [self createSmallBtn:@"-" frame:CGRectMake(cx, row1Y, 28, btnH)];
    [minusBtn addTarget:self action:@selector(clkSub) forControlEvents:UIControlEventTouchUpInside];
    [clickBox addSubview:minusBtn]; cx += 30;

    UITextField *intervalField = [[UITextField alloc] initWithFrame:CGRectMake(cx, row1Y, 52, btnH)];
    intervalField.text = @"0.5"; intervalField.textColor = [UIColor cyanColor];
    intervalField.font = [UIFont fontWithName:@"Menlo" size:11];
    intervalField.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.2].CGColor;
    intervalField.layer.borderWidth = 1; intervalField.layer.cornerRadius = 6;
    intervalField.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.04];
    intervalField.textAlignment = NSTextAlignmentCenter;
    intervalField.keyboardType = UIKeyboardTypeDecimalPad; intervalField.tag = 6002;
    [self addDoneButtonTo:intervalField];
    [clickBox addSubview:intervalField]; cx += 52;

    UILabel *secLabel = [[UILabel alloc] initWithFrame:CGRectMake(cx + 2, row1Y, 12, btnH)];
    secLabel.text = @"s"; secLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.3];
    secLabel.font = [UIFont systemFontOfSize:10];
    [clickBox addSubview:secLabel]; cx += 14;

    UIButton *plusBtn = [self createSmallBtn:@"+" frame:CGRectMake(cx, row1Y, 28, btnH)];
    [plusBtn addTarget:self action:@selector(clkAdd) forControlEvents:UIControlEventTouchUpInside];
    [clickBox addSubview:plusBtn];

    CGFloat rightX = colW / 2 + 4;
    UISwitch *touchSwitch = [[UISwitch alloc] init];
    touchSwitch.transform = CGAffineTransformMakeScale(0.55, 0.55);
    touchSwitch.frame = CGRectMake(rightX, row1Y, 51, btnH);
    touchSwitch.onTintColor = [UIColor cyanColor]; touchSwitch.on = g_touchPassthroughMode;
    [touchSwitch addTarget:self action:@selector(onTouchModeToggle:) forControlEvents:UIControlEventValueChanged];
    [clickBox addSubview:touchSwitch];

    UILabel *touchLabel = [[UILabel alloc] initWithFrame:CGRectMake(rightX + 42, row1Y + 2, 120, btnH - 4)];
    touchLabel.text = VL(@"Tool_TouchMode");
    touchLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.5];
    touchLabel.font = [UIFont systemFontOfSize:10];
    [clickBox addSubview:touchLabel];

    // Row2: 点位按钮 + 启动
    CGFloat halfW = (colW - innerPad * 2 - 6) / 2;
    UIButton *ptBtn = [self createSmallBtn:VL(@"Click_AddPt") frame:CGRectMake(innerPad, row2Y, halfW * 0.5 - 3, btnH)];
    [ptBtn addTarget:self action:@selector(clkPt) forControlEvents:UIControlEventTouchUpInside];
    [clickBox addSubview:ptBtn];

    UIButton *undoBtn = [self createSmallBtn:VL(@"Click_Undo") frame:CGRectMake(innerPad + halfW * 0.5 + 3, row2Y, halfW * 0.5 - 3, btnH)];
    [undoBtn addTarget:self action:@selector(clkUndo) forControlEvents:UIControlEventTouchUpInside];
    [clickBox addSubview:undoBtn];

    UIButton *startBtn = [self createSmallBtn:VL(@"Click_Start") frame:CGRectMake(innerPad + halfW + 6, row2Y, halfW, btnH)];
    startBtn.tag = 6001;
    [startBtn addTarget:self action:@selector(clkToggle) forControlEvents:UIControlEventTouchUpInside];
    [clickBox addSubview:startBtn];

    [_toolsScroll addSubview:clickBox];
    y += clickH + gap;

    // ═══ 配置管理 + Dump ═══
    CGFloat halfCol = (colW - gap) / 2;
    UIView *configBox = [self createBox:VL(@"Tool_Config") x:pad y:y w:halfCol];
    configBox.frame = CGRectMake(pad, y, halfCol, rowH);

    CGFloat configBtnGap = 6;
    CGFloat configBtnW = floor((halfCol - innerPad * 2 - configBtnGap) / 2.0);
    UIButton *importBtn = [self createSmallBtn:VL(@"Config_Import") frame:CGRectMake(innerPad, row1Y, configBtnW, btnH)];
    [importBtn addTarget:self action:@selector(importConfig) forControlEvents:UIControlEventTouchUpInside];
    [configBox addSubview:importBtn];

    UIButton *deleteBtn = [self createSmallBtn:VL(@"Config_Delete") frame:CGRectMake(innerPad + configBtnW + configBtnGap, row1Y, configBtnW, btnH)];
    deleteBtn.layer.borderColor = [[UIColor orangeColor] colorWithAlphaComponent:0.5].CGColor;
    [deleteBtn setTitleColor:[[UIColor orangeColor] colorWithAlphaComponent:0.8] forState:UIControlStateNormal];
    deleteBtn.backgroundColor = [[UIColor orangeColor] colorWithAlphaComponent:0.05];
    [deleteBtn addTarget:self action:@selector(deleteConfig) forControlEvents:UIControlEventTouchUpInside];
    [configBox addSubview:deleteBtn];
    [_toolsScroll addSubview:configBox];

    UIView *dumpBox = [self createBox:VL(@"Tool_Dump") x:pad + halfCol + gap y:y w:halfCol];
    dumpBox.frame = CGRectMake(pad + halfCol + gap, y, halfCol, rowH);

    UIButton *dumpBtn = [self createSmallBtn:VL(@"Dump_Btn") frame:CGRectMake(innerPad, row1Y, halfCol - innerPad * 2, btnH)];
    [dumpBtn addTarget:self action:@selector(onDump) forControlEvents:UIControlEventTouchUpInside];
    [dumpBox addSubview:dumpBtn];
    [_toolsScroll addSubview:dumpBox];
    y += rowH + gap;

    // ═══ 文件浏览器 + 语言 ═══
    UIView *fileBox = [self createBox:VL(@"FileBrowser_Title") x:pad y:y w:halfCol];
    fileBox.frame = CGRectMake(pad, y, halfCol, rowH);

    UIButton *fileBtn = [self createSmallBtn:VL(@"FileBrowser_Open") frame:CGRectMake(innerPad, row1Y, halfCol - innerPad * 2, btnH)];
    [fileBtn addTarget:self action:@selector(onOpenFileBrowser) forControlEvents:UIControlEventTouchUpInside];
    [fileBox addSubview:fileBtn];
    [_toolsScroll addSubview:fileBox];

    UIView *langBox = [self createBox:VL(@"About_Lang") x:pad + halfCol + gap y:y w:halfCol];
    langBox.frame = CGRectMake(pad + halfCol + gap, y, halfCol, rowH);

    NSString *currentLangName = [[VLocalization shared] currentLanguageName];
    UIButton *langBtn = [self createSmallBtn:currentLangName frame:CGRectMake(innerPad, row1Y, halfCol - innerPad * 2, btnH)];
    langBtn.tag = 6003;
    [langBtn addTarget:self action:@selector(onLangPicker) forControlEvents:UIControlEventTouchUpInside];
    [langBox addSubview:langBtn];
    [_toolsScroll addSubview:langBox];
    y += rowH + gap;

    _toolsScroll.contentSize = CGSizeMake(w, y + pad);
    _pageTools.frame = CGRectMake(0, 0, w, MAX(bodyH, y + pad));
}

#pragma mark - About Page

- (void)setupAboutPage:(CGFloat)w {
    CGFloat bodyH = _panelBody.frame.size.height;
    _pageAbout = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, bodyH)];
    _pageAbout.hidden = YES;
    [_panelBody addSubview:_pageAbout];

    _aboutScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, bodyH)];
    _aboutScroll.showsVerticalScrollIndicator = NO;
    [_pageAbout addSubview:_aboutScroll];

    [self buildAboutContent:w];
}

- (void)buildAboutContent:(CGFloat)w {
    [VLAbout setupAboutView:_aboutScroll];
}

#pragma mark - TableView DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView.tag == 2001) {
        // 内存搜索结果
        NSUInteger total = [VMemEngine shared].resultCount;
        NSUInteger start = _memResultPage * kPageSize;
        return (NSInteger)MIN(kPageSize, (total > start) ? (total - start) : 0);
    }
    if (tableView.tag == 2002) {
        // 工具箱
        if (_currentSubTab == VLToolboxSubWatch || _currentSubTab == VLToolboxSubBrowser) return 0;
        NSUInteger total = [self tbDataSource].count;
        NSUInteger start = _tbPage * kPageSize;
        return (NSInteger)MIN(kPageSize, (total > start) ? (total - start) : 0);
    }
    if (tableView.tag == 3010) {
        // Watch slots
        return [VLDebugEngine isAvailable] ? (NSInteger)[VLDebugEngine shared].maxSlots : 0;
    }
    if (tableView.tag == 3011) {
        // Watch hits
        if (_watchSelectedSlot >= 0) return (NSInteger)[[VLDebugEngine shared] hitsForSlot:(uint32_t)_watchSelectedSlot].count;
        return (NSInteger)_watchHits.count;
    }
    if (tableView.tag == 3020) {
        // Browser
        return (NSInteger)_browserMemoryData.count;
    }
    if (tableView.tag == 3040) {
        // Watch inspector
        return (NSInteger)_watchInspectLines.count;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.tag == 2001) return [self memResultCellForIndex:indexPath.row];
    if (tableView.tag == 2002) return [self tbCellForIndex:indexPath.row];
    if (tableView.tag == 3010) return [self watchFusionSlotCellForRow:indexPath.row];
    if (tableView.tag == 3011) return [self watchFusionHitCellForRow:indexPath.row];
    if (tableView.tag == 3020) return [self browserFusionCellForRow:indexPath.row];
    if (tableView.tag == 3040) return [self watchInspectCellForRow:indexPath.row];
    return [[UITableViewCell alloc] init];
}

#pragma mark - TableView Delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.tag == 2001) return 52;
    if (tableView.tag == 2002) {
        if (_currentSubTab == VLToolboxSubLock) return 48;
        if (_currentSubTab == VLToolboxSubScript) return 60;
        return UITableViewAutomaticDimension;
    }
    if (tableView.tag == 3010) return 48;
    if (tableView.tag == 3011) return 52;
    if (tableView.tag == 3020) return 40;
    if (tableView.tag == 3040) return 28;
    return 44;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.tag == 2001) {
        if (_memMultiSelectMode) {
            [self toggleMemorySelectionAtIndexPath:indexPath];
            return;
        }
        // 内存搜索结果 - 点击写值
        NSUInteger idx = _memResultPage * kPageSize + indexPath.row;
        VMemResultItem *item = [[VMemEngine shared] getResultAtIndex:idx type:g_currentType];
        if (item && g_currentType != VMemDataTypeString) {
            [self showWriteValueAlert:item];
        }
    }
    if (tableView.tag == 2002) {
        NSUInteger idx = _tbPage * kPageSize + indexPath.row;
        NSMutableArray *ds = [self tbDataSource];
        if (idx >= ds.count) return;
        if (_currentSubTab == VLToolboxSubLock) {
            [self showTbMemItemActions:ds[idx] atIndex:idx];
        } else if (_currentSubTab == VLToolboxSubScript) {
            [self showScriptActions:ds[idx] atIndex:idx];
        }
    }
    if (tableView.tag == 3010) {
        // Watch slot 选择
        _watchSelectedSlot = indexPath.row;
        [_watchSlotTable reloadData];
        [_watchHitTable reloadData];
    }
    if (tableView.tag == 3020) {
        if (_browserMultiSelectMode) {
            [self toggleBrowserSelectionAtIndexPath:indexPath];
            return;
        }
        // Browser - 点击写值
        if (indexPath.row < (NSInteger)_browserMemoryData.count) {
            NSMutableDictionary *item = _browserMemoryData[indexPath.row];
            uint64_t addr = [item[@"addr"] unsignedLongLongValue];
            VMemDataType type = [self browserCurrentType];
            VMemResultItem *ri = [[VMemResultItem alloc] init];
            ri.address = addr;
            ri.type = type;
            ri.valueStr = item[@"value"];
            if (type != VMemDataTypeString && _browserTypeSeg.selectedSegmentIndex != 4) {
                [self showWriteValueAlert:ri];
            }
        }
    }
    if (tableView.tag == 3040) {
        // Watch inspector - 选择行
        [self onWatchInspectSelectRow:indexPath.row];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.tag == 2002 && _currentSubTab != VLToolboxSubLock && _currentSubTab != VLToolboxSubScript
        && _currentSubTab != VLToolboxSubWatch && _currentSubTab != VLToolboxSubBrowser) {
        NSUInteger idx = _tbPage * kPageSize + indexPath.row;
        NSMutableArray *ds = [self tbDataSource];
        if (idx >= ds.count) return nil;
        VModItem *item = ds[idx];

        UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:VL(@"Btn_Delete") handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
            [ds removeObjectAtIndex:idx];
            [VModParser saveConfig];
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [self updateTbPager];
            completionHandler(YES);
        }];

        UIContextualAction *editAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:VL(@"Btn_Edit") handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
            [VItemEditor showEditorForItem:item fromWindow:GetSafeWindow() delegate:self];
            completionHandler(YES);
        }];
        editAction.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.8 alpha:1];

        return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, editAction]];
    }
    return nil;
}

#pragma mark - ScrollView Delegate (Browser auto-load)

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == _browserTable && !_browserIsLoading && !_browserIsInitialLoad) {
        CGFloat offsetY = scrollView.contentOffset.y;
        CGFloat contentH = scrollView.contentSize.height;
        CGFloat frameH = scrollView.frame.size.height;

        if (offsetY + frameH > contentH - BROWSER_PRELOAD_THRESHOLD) {
            [self browserLoadMoreData:YES];
        }
        if (offsetY < BROWSER_PRELOAD_THRESHOLD) {
            [self browserLoadMoreData:NO];
        }
    }
}

#pragma mark - VModCellDelegate

- (void)cellDidRequestEdit:(VLModItem *)item {
    [VItemEditor showEditorForItem:item fromWindow:GetSafeWindow() delegate:self];
}

- (void)cellDidToggleLock:(VLModItem *)item isLocked:(BOOL)locked {
    item.isLocked = locked;
    if (locked) {
        // 读取当前值作为锁定值
        NSString *curr = nil;
        if (item.type == VModTypePointer) {
            curr = [[VModEngine shared] readPointerValue:item];
        } else if (item.type == VModTypeSignature) {
            curr = [[VModEngine shared] readSignatureValue:item];
        }
        if (curr && ![curr containsString:@"("] && ![curr isEqualToString:@"?"]) {
            item.lockValue = curr;
        } else if (!item.lockValue || item.lockValue.length == 0) {
            item.lockValue = @"0";
        }
    } else {
        item.lockValue = @"";
    }
    [VModParser saveConfig];
    [_tbTable reloadData];
}

- (void)cellDidToggleEnabled:(VLModItem *)item isEnabled:(BOOL)enabled {
    item.isEnabled = enabled;
    [VModParser saveConfig];
}

- (void)cellDidToggleRVA:(VLModItem *)item {
    [[VModEngine shared] toggleRVA:item];
    [VModParser saveConfig];
    [_tbTable reloadData];
}

- (void)cellDidChangeSlider:(VLModItem *)item value:(float)value {
    NSString *val = [NSString stringWithFormat:@"%g", value];
    if (item.type == VModTypePointer) {
        [[VModEngine shared] writePointerValue:item value:val];
    } else if (item.type == VModTypeSignature) {
        [[VModEngine shared] writeSignatureValue:item value:val];
    }
}

- (void)cellDidToggleSwitch:(VLModItem *)item isOn:(BOOL)isOn {
    NSString *val = isOn ? (item.switchOnValue ?: @"1") : (item.switchOffValue ?: @"0");
    if (item.type == VModTypePointer) {
        [[VModEngine shared] writePointerValue:item value:val];
    } else if (item.type == VModTypeSignature) {
        [[VModEngine shared] writeSignatureValue:item value:val];
    }
}

- (void)cellDidRequestMatch:(VLModItem *)item {
    NSArray<NSNumber *> *results = [[VModEngine shared] searchSignature:item.signature inModule:item.moduleName];
    item.multiAddresses = results;
    [VModParser saveConfig];
    [_tbTable reloadData];
    showToast([NSString stringWithFormat:@"%@ %lu", VL(@"Mem_Found"), (unsigned long)results.count]);
}

- (void)cellDidClickResultValue:(VLModItem *)item atIndex:(NSInteger)index address:(uint64_t)addr currentValue:(NSString *)val {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"0x%llX", addr] message:nil preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = val; tf.keyboardType = UIKeyboardTypeDecimalPad;
        tf.placeholder = VL(@"Mem_NewValue");
    }];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Mem_Write") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *newVal = ac.textFields.firstObject.text;
        if (newVal.length > 0) {
            [[VModEngine shared] writeSignatureValue:item value:newVal];
            [self->_tbTable reloadData];
        }
    }]];
    [[GetSafeWindow() rootViewController] presentViewController:ac animated:YES completion:nil];
}

- (void)cellDidChangeModeSegment:(VLModItem *)item atIndex:(NSInteger)index mode:(VMUIMode)mode {
    item.uiMode = mode;
    [VModParser saveConfig];
    [_tbTable reloadData];
}

- (void)cellDidChangeResultSlider:(VLModItem *)item atIndex:(NSInteger)index value:(NSString *)value {
    [[VModEngine shared] writeSignatureValue:item value:value];
}

- (void)cellDidChangeResultSwitch:(VLModItem *)item atIndex:(NSInteger)index isOn:(BOOL)isOn {
    NSString *val = isOn ? (item.switchOnValue ?: @"1") : (item.switchOffValue ?: @"0");
    [[VModEngine shared] writeSignatureValue:item value:val];
}

#pragma mark - VItemEditorDelegate

- (void)editorDidSaveItem:(VLModItem *)item {
    [VModParser saveConfig];
    [_tbTable reloadData];
    showToast(VL(@"Msg_Saved"));
}

- (void)editorDidDeleteItem:(VLModItem *)item {
    NSMutableArray *ds = nil;
    switch (item.type) {
        case VModTypePointer: ds = g_ptrItems; break;
        case VModTypeRVA: ds = g_rvaItems; break;
        case VModTypeSignature: ds = g_sigItems; break;
        default: break;
    }
    if (ds) {
        [ds removeObject:item];
        [VModParser saveConfig];
        [_tbTable reloadData];
        [self updateTbPager];
    }
}

#pragma mark - Tools Page Actions

- (void)clkSub { [VLTools clkSub]; }
- (void)clkAdd { [VLTools clkAdd]; }
- (void)clkPt  { [VLTools clkPt]; }
- (void)clkUndo { [VLTools clkUndo]; }

- (void)clkToggle {
    [VLTools clkToggle];
    UIButton *startBtn = [_toolsScroll viewWithTag:6001];
    if (startBtn) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *title = g_clickerRunning ? VL(@"Click_Stop") : VL(@"Click_Start");
            [startBtn setTitle:title forState:UIControlStateNormal];
        });
    }
}

- (void)onDump { [VLDumpManager dumpUnityFiles]; }

- (void)onTouchModeToggle:(UISwitch *)toggle {
    [VLTools onTouchModeToggle:toggle];
}

- (void)onOpenFileBrowser {
    UIWindow *w = GetSafeWindow();
    if (w) [VLFileBrowserVC showFromWindow:w];
}

- (void)openTelegram {
    NSURL *url = [NSURL URLWithString:@"https://t.me/VansonMod"];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)onDisclaimerTap {
    [VLAbout onDisclaimerTapped];
}

#pragma mark - Language Picker

- (void)onLangPicker {
    NSArray *languages = [[VLocalization shared] supportedLanguages];
    NSInteger currentIdx = [[VLocalization shared] currentLanguage];

    UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"About_Lang") message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSInteger i = 0; i < (NSInteger)languages.count; i++) {
        NSDictionary *lang = languages[i];
        NSString *title = lang[@"native"];
        if (i == currentIdx) title = [NSString stringWithFormat:@"✓ %@", title];

        [ac addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [self onLangSelected:@(i)];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];

    if (ac.popoverPresentationController) {
        ac.popoverPresentationController.sourceView = _bgView;
        ac.popoverPresentationController.sourceRect = CGRectMake(_bgView.bounds.size.width / 2, _bgView.bounds.size.height / 2, 1, 1);
    }
    UIViewController *vc = GetSafeWindow().rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    [vc presentViewController:ac animated:YES completion:nil];
}

- (void)onLangSelected:(NSNumber *)idx {
    [[VLocalization shared] setLanguage:[idx integerValue]];
    showToast(VL(@"Msg_LangChanged"));
}

- (void)dismissLangPicker {
    // no-op, handled by alert dismiss
}

#pragma mark - Icon Picker

- (void)onLogoTap {
    NSArray *icons = [VLIconManager allKeys];
    if (icons.count == 0) return;

    UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"About_Icon") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *key in icons) {
        [ac addAction:[UIAlertAction actionWithTitle:key style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [self onIconSelected:key];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];

    if (ac.popoverPresentationController) {
        ac.popoverPresentationController.sourceView = _bgView;
        ac.popoverPresentationController.sourceRect = CGRectMake(_bgView.bounds.size.width / 2, 22, 1, 1);
    }
    UIViewController *vc = GetSafeWindow().rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    [vc presentViewController:ac animated:YES completion:nil];
}

- (void)onIconSelected:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"Vanson_SelectedIcon"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    showToast(VL(@"Msg_IconChanged"));
}

- (void)dismissIconPicker {
    // no-op
}

#pragma mark - Config Import / Delete

- (void)importConfig {
    UIDocumentPickerViewController *picker;
    if (@available(iOS 14.0, *)) {
        picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType typeWithIdentifier:@"public.data"]] asCopy:YES];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data", @"public.item"] inMode:UIDocumentPickerModeImport];
#pragma clang diagnostic pop
    }
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;

    UIViewController *vc = GetSafeWindow().rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    [vc presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSSet<NSString *> *allowedExtensions = [NSSet setWithArray:@[@"vmpt", @"vmrva", @"vmsig", @"vmsc", @"vmvapt", @"vmps"]];
    NSInteger importedCount = 0;

    for (NSURL *url in urls) {
        NSString *ext = url.pathExtension.lowercaseString;
        if (![ext hasPrefix:@"vm"] && ![allowedExtensions containsObject:ext]) {
            continue;
        }

        BOOL accessing = [url startAccessingSecurityScopedResource];
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (accessing) [url stopAccessingSecurityScopedResource];
        if (!data) continue;

        importedCount += [VModParser importVM24Data:data];
    }

    if (importedCount <= 0) {
        showToast(VL(@"Msg_ImportError"));
        return;
    }

    [_tbTable reloadData];
    [self updateTbPager];
    showToast(VL(@"Msg_ImportSuccess"));
}

- (void)deleteConfig {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"Config_Delete") message:VL(@"Config_Delete_Msg") preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Confirm") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [g_ptrItems removeAllObjects];
        [g_rvaItems removeAllObjects];
        [g_sigItems removeAllObjects];
        [g_scriptItems removeAllObjects];
        [VModParser saveConfig];
        [self->_tbTable reloadData];
        [self updateTbPager];
        showToast(VL(@"Config_Deleted"));
    }]];
    [[GetSafeWindow() rootViewController] presentViewController:ac animated:YES completion:nil];
}

#pragma mark - Notifications

- (void)onLanguageChanged {
    CGFloat w = _bgView.frame.size.width;
    // 重建导航栏
    for (UIView *v in _navBar.subviews) [v removeFromSuperview];
    [_navBar removeFromSuperview];
    [self setupNavBar:w];

    // 重建各页面内容
    [self buildToolsContent:w];
    [self buildAboutContent:w];
    [self rebuildMemToolbar];
    [self updateMemUIForMode];
    [self rebuildTbBottomButtons];
    [self updateSubTabHighlight];

    // 更新语言按钮
    UIButton *langBtn = [_toolsScroll viewWithTag:6003];
    if (langBtn) [langBtn setTitle:[[VLocalization shared] currentLanguageName] forState:UIControlStateNormal];
}

- (void)onMemResultsReceived:(NSNotification *)note {
    [self refreshMemResults];
}

- (void)onMemItemLocked:(NSNotification *)note {
    NSDictionary *info = note.userInfo;
    if (!info) return;
    uint64_t addr = [info[@"address"] unsignedLongLongValue];
    NSString *val = info[@"value"] ?: @"0";
    VMemDataType type = (VMemDataType)[info[@"type"] integerValue];

    _memLockedItems[@(addr)] = @{@"value": val, @"type": @(type)};

    BOOL exists = NO;
    for (VLPanelMemItem *mi in _tbMemResults) {
        if (mi.address == addr) { mi.isLocked = YES; mi.lockValue = val; exists = YES; break; }
    }
    if (!exists) {
        VLPanelMemItem *mi = [[VLPanelMemItem alloc] init];
        mi.address = addr; mi.dataType = type;
        mi.currentValue = val; mi.isLocked = YES; mi.lockValue = val;
        [_tbMemResults addObject:mi];
    }
    [_memResultsTable reloadData];
    if (_currentSubTab == VLToolboxSubLock) [_tbTable reloadData];
}

- (void)onMemItemUnlocked:(NSNotification *)note {
    NSDictionary *info = note.userInfo;
    if (!info) return;
    uint64_t addr = [info[@"address"] unsignedLongLongValue];
    [_memLockedItems removeObjectForKey:@(addr)];

    for (NSInteger i = (NSInteger)_tbMemResults.count - 1; i >= 0; i--) {
        VLPanelMemItem *mi = _tbMemResults[i];
        if (mi.address == addr) { [_tbMemResults removeObjectAtIndex:i]; break; }
    }
    [_memResultsTable reloadData];
    if (_currentSubTab == VLToolboxSubLock) [_tbTable reloadData];
}

- (void)onWatchHitReceived:(NSNotification *)note {
    VLWatchHit *hit = note.userInfo[@"hit"];
    if (hit) {
        [_watchHits addObject:hit];
        if (_currentTab == VLMainTabToolbox && _currentSubTab == VLToolboxSubWatch) {
            [_watchHitTable reloadData];
            [_watchSlotTable reloadData];
        }
    }
}

#pragma mark - Lock Timers

- (void)updateMemLocks {
    if (_memLockedItems.count == 0) return;
    VMemEngine *engine = [VMemEngine shared];
    if (!engine.isReady) return;

    for (NSNumber *addrKey in _memLockedItems) {
        NSDictionary *info = _memLockedItems[addrKey];
        [engine writeAddress:[addrKey unsignedLongLongValue] value:info[@"value"] type:(VMemDataType)[info[@"type"] integerValue]];
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    if (textField == _memValueField) {
        [self doMemSearch];
    }
    return YES;
}

#pragma mark - UI Helpers

- (void)styleSegment:(UISegmentedControl *)seg {
    seg.backgroundColor = [VLSurfaceColor() colorWithAlphaComponent:0.8];
    seg.tintColor = VLAccentColor();
    if (@available(iOS 13.0, *)) {
        seg.selectedSegmentTintColor = [VLAccentColor() colorWithAlphaComponent:0.22];
    }
    NSDictionary *normalAttr = @{NSForegroundColorAttributeName: [VLAccentColor() colorWithAlphaComponent:0.55],
                                  NSFontAttributeName: [UIFont fontWithName:@"Menlo" size:9]};
    NSDictionary *selAttr = @{NSForegroundColorAttributeName: VLAccentColor(),
                               NSFontAttributeName: [UIFont fontWithName:@"Menlo-Bold" size:9]};
    [seg setTitleTextAttributes:normalAttr forState:UIControlStateNormal];
    [seg setTitleTextAttributes:selAttr forState:UIControlStateSelected];
}

- (UIView *)createBox:(NSString *)title x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w {
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, 100)];
    box.backgroundColor = VLSurfaceColor();
    box.layer.cornerRadius = 12;
    box.layer.borderWidth = 1;
    box.layer.borderColor = VLStrokeColor().CGColor;

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(10, 4, w - 20, 18)];
    lbl.text = title;
    lbl.textColor = VLAccentColor();
    lbl.font = [UIFont boldSystemFontOfSize:10];
    [box addSubview:lbl];
    return box;
}

- (UIButton *)createSmallBtn:(NSString *)title frame:(CGRect)frame {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = frame;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:VLAccentColor() forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:10];
    btn.layer.cornerRadius = 8;
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [VLAccentColor() colorWithAlphaComponent:0.32].CGColor;
    btn.backgroundColor = [VLAccentColor() colorWithAlphaComponent:0.08];
    return btn;
}

- (void)addDoneButtonTo:(UITextField *)tf {
    UIToolbar *bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 280, 44)];
    bar.barStyle = UIBarStyleBlack;
    bar.tintColor = VLAccentColor();
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:tf action:@selector(resignFirstResponder)];
    bar.items = @[flex, done];
    tf.inputAccessoryView = bar;
}

- (size_t)sizeForType:(VMDataType)type {
    switch (type) {
        case VMemDataTypeI8: case VMemDataTypeU8: return 1;
        case VMemDataTypeI16: case VMemDataTypeU16: return 2;
        case VMemDataTypeI32: case VMemDataTypeU32: case VMemDataTypeF32: return 4;
        case VMemDataTypeI64: case VMemDataTypeU64: case VMemDataTypeF64: return 8;
        default: return 4;
    }
}

- (NSData *)dataFromValue:(NSString *)value type:(VMDataType)type {
    switch (type) {
        case VMemDataTypeI8: { int8_t v = (int8_t)[value intValue]; return [NSData dataWithBytes:&v length:1]; }
        case VMemDataTypeU8: { uint8_t v = (uint8_t)[value intValue]; return [NSData dataWithBytes:&v length:1]; }
        case VMemDataTypeI16: { int16_t v = (int16_t)[value intValue]; return [NSData dataWithBytes:&v length:2]; }
        case VMemDataTypeU16: { uint16_t v = (uint16_t)[value intValue]; return [NSData dataWithBytes:&v length:2]; }
        case VMemDataTypeI32: { int32_t v = (int32_t)[value intValue]; return [NSData dataWithBytes:&v length:4]; }
        case VMemDataTypeU32: { uint32_t v = (uint32_t)[value longLongValue]; return [NSData dataWithBytes:&v length:4]; }
        case VMemDataTypeI64: { int64_t v = [value longLongValue]; return [NSData dataWithBytes:&v length:8]; }
        case VMemDataTypeU64: { uint64_t v = strtoull([value UTF8String], NULL, 10); return [NSData dataWithBytes:&v length:8]; }
        case VMemDataTypeF32: { float v = [value floatValue]; return [NSData dataWithBytes:&v length:4]; }
        case VMemDataTypeF64: { double v = [value doubleValue]; return [NSData dataWithBytes:&v length:8]; }
        default: return nil;
    }
}

@end

#pragma mark - VLPanel 公共 API

#import "VLPanel.h"

@implementation VLPanel

+ (void)attachPanelToCurrentWindowIfNeeded {
    if (!g_panel) return;
    UIWindow *w = GetSafeWindow();
    if (!w) return;
    if (g_panel.superview != w) {
        [g_panel removeFromSuperview];
        g_panel.frame = w.bounds;
        [w addSubview:g_panel];
    } else if (!CGRectEqualToRect(g_panel.frame, w.bounds)) {
        g_panel.frame = w.bounds;
    }
}

+ (void)initializeIfNeeded {
    if (g_panel) {
        [self attachPanelToCurrentWindowIfNeeded];
        return;
    }
    UIWindow *w = GetSafeWindow();
    if (!w) return;

    g_panel = [[VPanelImpl alloc] initWithFrame:w.bounds];
    g_panel.hidden = YES;
    [w addSubview:g_panel];
}

+ (void)show {
    if (!g_panel) [self initializeIfNeeded];
    if (!g_panel) return;
    [self attachPanelToCurrentWindowIfNeeded];
    [g_panel.superview bringSubviewToFront:g_panel];
    [g_panel showWithAnimation];
}

+ (void)hide {
    if (g_panel) [g_panel hideWithAnimation];
}

+ (void)toggle {
    if (!g_panel) { [self show]; return; }
    if (g_panel.hidden) [self show]; else [self hide];
}

+ (void)reloadList {
    if (g_panel) {
        [g_panel.tbTable reloadData];
        [g_panel updateTbPager];
    }
}

+ (void)updateTabsVisibility {
    // 所有Tab始终可见
}

@end
