/**
 * VansonLoader L2.7 - VLPanelMemory
 * 内存搜索Tab: UI构建、搜索逻辑、结果Cell、批量操作
 */

#import "VLPanel+Internal.h"

static VMemDataType VLNearbyTypeForSelection(NSInteger index) {
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

static NSString *VLPanelTimelineTypeName(VMemDataType type) {
    NSArray *names = @[@"I8", @"I16", @"I32", @"I64", @"U8", @"U16", @"U32", @"U64", @"F32", @"F64", @"Str"];
    if (type < names.count) return names[type];
    return @"?";
}

static NSString *VLPanelTimelineModeTitle(VMemSearchMode mode) {
    switch (mode) {
        case VMemSearchModeFuzzy: return VL(@"Timeline_Mode_Fuzzy");
        case VMemSearchModeGroup: return VL(@"Timeline_Mode_Group");
        case VMemSearchModeBetween: return VL(@"Timeline_Mode_Between");
        case VMemSearchModeExact:
        default: return VL(@"Timeline_Mode_Exact");
    }
}

static NSString *VLPanelTimelineFilterTitle(VMemFilterMode mode) {
    switch (mode) {
        case VMemFilterModeGreater: return VL(@"Fuz_Increased");
        case VMemFilterModeLess: return VL(@"Fuz_Decreased");
        case VMemFilterModeChanged: return VL(@"Fuz_Changed");
        case VMemFilterModeUnchanged: return VL(@"Fuz_Unchanged");
        case VMemFilterModeIncreased: return VL(@"Fuz_Increased");
        case VMemFilterModeDecreased: return VL(@"Fuz_Decreased");
        case VMemFilterModeBetween: return VL(@"Timeline_Mode_Between");
    }
}

static void VLPanelCaptureTimeline(NSString *title, NSString *detail, VMemDataType type) {
    [[VMemEngine shared] captureTimelineWithTitle:title ?: @""
                                           detail:detail ?: @""
                                         dataType:type];
}

@implementation VPanelImpl (Memory)

#pragma mark - Memory Page Setup (双栏)

- (void)setupMemoryPage:(CGFloat)w {
    CGFloat bodyH = self.panelBody.frame.size.height;
    self.pageMemory = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, bodyH)];
    [self.panelBody addSubview:self.pageMemory];

    CGFloat pad = 8;
    CGFloat colGap = 8;
    CGFloat leftW = (w - pad * 2 - colGap) * 0.45;
    CGFloat rightW = (w - pad * 2 - colGap - leftW);
    CGFloat y = 0;

    // ═══ 搜索控件 ═══
    UIView *searchBox = [self createBox:VL(@"Mem_Debug_Title") x:pad y:y w:leftW];

    self.memModeSeg = [[UISegmentedControl alloc] initWithItems:@[VL(@"Mem_Tab_Exact"), VL(@"Mem_Tab_Fuzzy"), VL(@"Mem_Tab_Group")]];
    self.memModeSeg.frame = CGRectMake(8, 22, leftW - 16, 24);
    self.memModeSeg.selectedSegmentIndex = 0;
    [self styleSegment:self.memModeSeg];
    [self.memModeSeg addTarget:self action:@selector(memModeChanged) forControlEvents:UIControlEventValueChanged];
    [searchBox addSubview:self.memModeSeg];

    UILabel *typeLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 50, leftW - 16, 14)];
    typeLabel.text = VL(@"Edit_DataType");
    typeLabel.textColor = [UIColor cyanColor];
    typeLabel.font = [UIFont boldSystemFontOfSize:10];
    [searchBox addSubview:typeLabel];

    self.memTypeSeg = [[UISegmentedControl alloc] initWithItems:@[@"I8", @"I16", @"I32", @"I64", @"U8", @"U16", @"U32", @"U64"]];
    self.memTypeSeg.frame = CGRectMake(8, 66, leftW - 16, 22);
    self.memTypeSeg.selectedSegmentIndex = 2;
    [self styleSegment:self.memTypeSeg];
    [self.memTypeSeg addTarget:self action:@selector(memTypeChanged:) forControlEvents:UIControlEventValueChanged];
    [searchBox addSubview:self.memTypeSeg];

    self.memTypeSeg2 = [[UISegmentedControl alloc] initWithItems:@[@"F32", @"F64", @"Str"]];
    self.memTypeSeg2.frame = CGRectMake(8, 90, (leftW - 16) * 0.5, 22);
    self.memTypeSeg2.selectedSegmentIndex = UISegmentedControlNoSegment;
    [self styleSegment:self.memTypeSeg2];
    [self.memTypeSeg2 addTarget:self action:@selector(memType2Changed:) forControlEvents:UIControlEventValueChanged];
    [searchBox addSubview:self.memTypeSeg2];

    self.memValueField = [[UITextField alloc] initWithFrame:CGRectMake(8, 116, leftW - 16, 28)];
    self.memValueField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:VL(@"Mem_InputValue") attributes:@{NSForegroundColorAttributeName: [[UIColor cyanColor] colorWithAlphaComponent:0.18]}];
    self.memValueField.textColor = [UIColor cyanColor];
    self.memValueField.font = [UIFont fontWithName:@"Menlo" size:11];
    self.memValueField.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.2].CGColor;
    self.memValueField.layer.borderWidth = 1;
    self.memValueField.layer.cornerRadius = 5;
    self.memValueField.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.04];
    self.memValueField.textAlignment = NSTextAlignmentCenter;
    self.memValueField.keyboardType = UIKeyboardTypeDecimalPad;
    self.memValueField.delegate = self;
    [self addDoneButtonTo:self.memValueField];
    [searchBox addSubview:self.memValueField];

    self.memFuzzyRow = [[UISegmentedControl alloc] initWithItems:@[VL(@"Fuz_Increased"), VL(@"Fuz_Decreased"), VL(@"Fuz_Unchanged"), VL(@"Fuz_Changed")]];
    self.memFuzzyRow.frame = CGRectMake(8, 116, leftW - 16, 26);
    self.memFuzzyRow.hidden = YES;
    [self styleSegment:self.memFuzzyRow];
    [searchBox addSubview:self.memFuzzyRow];

    self.memToolbar = [[UIView alloc] initWithFrame:CGRectMake(8, 148, leftW - 16, 26)];
    [searchBox addSubview:self.memToolbar];
    [self rebuildMemToolbar];

    searchBox.frame = CGRectMake(pad, y, leftW, 182);
    [self.pageMemory addSubview:searchBox];
    y += 182 + 6;

    // Console
    UIView *console = [[UIView alloc] initWithFrame:CGRectMake(pad, y, leftW, 26)];
    console.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
    console.layer.cornerRadius = 6;
    console.layer.borderWidth = 1;
    console.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.1].CGColor;
    [self.pageMemory addSubview:console];

    self.memConsoleLabel = [[UILabel alloc] initWithFrame:CGRectMake(6, 0, leftW - 12, 26)];
    self.memConsoleLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.6];
    self.memConsoleLabel.font = [UIFont fontWithName:@"Menlo" size:9];
    self.memConsoleLabel.textAlignment = NSTextAlignmentCenter;
    self.memConsoleLabel.text = VL(@"Mem_Ready");
    [console addSubview:self.memConsoleLabel];
    y += 32;

    // 临近搜索Box
    UIView *nearbyBox = [self createBox:VL(@"Nearby_Title") x:pad y:y w:leftW];

    self.nearbyValueField = [[UITextField alloc] initWithFrame:CGRectMake(8, 24, (leftW - 24) * 0.6, 24)];
    self.nearbyValueField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:VL(@"Nearby_Value") attributes:@{NSForegroundColorAttributeName: [[UIColor cyanColor] colorWithAlphaComponent:0.18]}];
    self.nearbyValueField.textColor = [UIColor cyanColor];
    self.nearbyValueField.font = [UIFont fontWithName:@"Menlo" size:10];
    self.nearbyValueField.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.2].CGColor;
    self.nearbyValueField.layer.borderWidth = 1;
    self.nearbyValueField.layer.cornerRadius = 5;
    self.nearbyValueField.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.04];
    self.nearbyValueField.textAlignment = NSTextAlignmentCenter;
    self.nearbyValueField.keyboardType = UIKeyboardTypeDecimalPad;
    [self addDoneButtonTo:self.nearbyValueField];
    [nearbyBox addSubview:self.nearbyValueField];

    self.nearbyRangeField = [[UITextField alloc] initWithFrame:CGRectMake(8 + (leftW - 24) * 0.6 + 4, 24, (leftW - 24) * 0.4 - 4, 24)];
    self.nearbyRangeField.text = @"512";
    self.nearbyRangeField.textColor = [UIColor cyanColor];
    self.nearbyRangeField.font = [UIFont fontWithName:@"Menlo" size:10];
    self.nearbyRangeField.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.2].CGColor;
    self.nearbyRangeField.layer.borderWidth = 1;
    self.nearbyRangeField.layer.cornerRadius = 5;
    self.nearbyRangeField.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.04];
    self.nearbyRangeField.textAlignment = NSTextAlignmentCenter;
    self.nearbyRangeField.keyboardType = UIKeyboardTypeNumberPad;
    self.nearbyRangeField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:VL(@"Nearby_Range") attributes:@{NSForegroundColorAttributeName: [[UIColor cyanColor] colorWithAlphaComponent:0.18]}];
    [self addDoneButtonTo:self.nearbyRangeField];
    [nearbyBox addSubview:self.nearbyRangeField];

    self.nearbyTypeSeg = [[UISegmentedControl alloc] initWithItems:@[@"I8", @"I16", @"I32", @"I64", @"F32", @"F64"]];
    self.nearbyTypeSeg.frame = CGRectMake(8, 52, leftW - 16, 22);
    [self styleSegment:self.nearbyTypeSeg];
    self.nearbyTypeSeg.selectedSegmentIndex = 2;
    [self.nearbyTypeSeg addTarget:self action:@selector(nearbyTypeChanged:) forControlEvents:UIControlEventValueChanged];
    [nearbyBox addSubview:self.nearbyTypeSeg];

    UIButton *nearbyBtn = [self createSmallBtn:VL(@"Nearby_Btn") frame:CGRectMake(8, 78, leftW - 16, 24)];
    [nearbyBtn addTarget:self action:@selector(doNearbySearch) forControlEvents:UIControlEventTouchUpInside];
    [nearbyBox addSubview:nearbyBtn];

    nearbyBox.frame = CGRectMake(pad, y, leftW, 110);
    [self.pageMemory addSubview:nearbyBox];
    [self syncMemoryTypeSegmentsFromGlobalType];
    CGFloat leftEndY = y + 110;

    // ═══ 搜索结果 (右栏) ═══
    CGFloat rightX = pad + leftW + colGap;
    CGFloat resultTop = 0;
    CGFloat resultH = bodyH - pad;

    UIView *resultBox = [[UIView alloc] initWithFrame:CGRectMake(rightX, resultTop, rightW, resultH)];
    resultBox.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.025];
    resultBox.layer.cornerRadius = 9;
    resultBox.layer.borderWidth = 1;
    resultBox.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.1].CGColor;
    [self.pageMemory addSubview:resultBox];

    UILabel *resTitle = [[UILabel alloc] initWithFrame:CGRectMake(rightX + 10, resultTop + 6, rightW - 174, 16)];
    resTitle.font = [UIFont boldSystemFontOfSize:10];
    resTitle.textColor = [UIColor cyanColor];
    resTitle.text = VL(@"Mem_Results");
    [self.pageMemory addSubview:resTitle];

    self.memSelectButton = [self createSmallBtn:VL(@"Batch_Select") frame:CGRectMake(rightX + rightW - 166, resultTop + 4, 44, 20)];
    self.memSelectButton.titleLabel.font = [UIFont boldSystemFontOfSize:8];
    [self.memSelectButton addTarget:self action:@selector(onMemSelectButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.pageMemory addSubview:self.memSelectButton];

    UIButton *refreshBtn = [self createSmallBtn:VL(@"Btn_Refresh") frame:CGRectMake(rightX + rightW - 120, resultTop + 4, 48, 20)];
    refreshBtn.titleLabel.font = [UIFont boldSystemFontOfSize:8];
    [refreshBtn addTarget:self action:@selector(manualRefreshMemResults) forControlEvents:UIControlEventTouchUpInside];
    [self.pageMemory addSubview:refreshBtn];

    self.memResultsCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(rightX + rightW - 70, resultTop + 6, 60, 16)];
    self.memResultsCountLabel.font = [UIFont fontWithName:@"Menlo" size:8];
    self.memResultsCountLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.3];
    self.memResultsCountLabel.textAlignment = NSTextAlignmentRight;
    [self.pageMemory addSubview:self.memResultsCountLabel];

    self.memResultsTable = [[UITableView alloc] initWithFrame:CGRectMake(rightX + 2, resultTop + 24, rightW - 4, resultH - 56) style:UITableViewStylePlain];
    self.memResultsTable.backgroundColor = [UIColor clearColor];
    self.memResultsTable.delegate = self;
    self.memResultsTable.dataSource = self;
    self.memResultsTable.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.memResultsTable.rowHeight = 52;
    self.memResultsTable.showsVerticalScrollIndicator = NO;
    self.memResultsTable.tag = 2001;
    [self.pageMemory addSubview:self.memResultsTable];

    UILongPressGestureRecognizer *memLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleMemResultLongPress:)];
    [self.memResultsTable addGestureRecognizer:memLongPress];

    UILabel *emptyLabel = [[UILabel alloc] initWithFrame:self.memResultsTable.bounds];
    emptyLabel.text = VL(@"Mem_Empty");
    emptyLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.35];
    emptyLabel.font = [UIFont systemFontOfSize:11];
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    emptyLabel.tag = 7001;
    emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.memResultsTable.backgroundView = emptyLabel;

    // 分页
    UIView *pagerView = [[UIView alloc] initWithFrame:CGRectMake(rightX, resultTop + resultH - 28, rightW, 24)];
    [self.pageMemory addSubview:pagerView];

    UIButton *prevBtn = [self createSmallBtn:@"<" frame:CGRectMake(10, 0, 30, 24)];
    [prevBtn addTarget:self action:@selector(memPrevPage) forControlEvents:UIControlEventTouchUpInside];
    [pagerView addSubview:prevBtn];

    self.memPageLabel = [[UILabel alloc] initWithFrame:CGRectMake(44, 0, rightW - 88, 24)];
    self.memPageLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.35];
    self.memPageLabel.font = [UIFont fontWithName:@"Menlo" size:9];
    self.memPageLabel.textAlignment = NSTextAlignmentCenter;
    self.memPageLabel.text = @"0 / 0";
    [pagerView addSubview:self.memPageLabel];

    UIButton *nextBtn = [self createSmallBtn:@">" frame:CGRectMake(rightW - 40, 0, 30, 24)];
    [nextBtn addTarget:self action:@selector(memNextPage) forControlEvents:UIControlEventTouchUpInside];
    [pagerView addSubview:nextBtn];

    CGFloat totalH = MAX(bodyH, leftEndY + pad);
    self.pageMemory.frame = CGRectMake(0, 0, w, totalH);
}


#pragma mark - Memory Search Logic

- (void)memModeChanged {
    [self updateMemUIForMode];
}

- (void)updateMemUIForMode {
    NSInteger mode = self.memModeSeg.selectedSegmentIndex;
    BOOL isFuzzy = (mode == 1);

    if (isFuzzy && self.memIsNextScan) {
        self.memFuzzyRow.hidden = NO;
        self.memValueField.hidden = YES;
    } else {
        self.memFuzzyRow.hidden = YES;
        self.memValueField.hidden = NO;
        self.memValueField.userInteractionEnabled = !(isFuzzy && !self.memIsNextScan);
        if (isFuzzy && !self.memIsNextScan) {
            self.memValueField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:VL(@"Fuz_First_Hint") attributes:@{NSForegroundColorAttributeName: [[UIColor cyanColor] colorWithAlphaComponent:0.18]}];
        } else if (mode == 2) {
            self.memValueField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:VL(@"Mem_GroupHint") attributes:@{NSForegroundColorAttributeName: [[UIColor cyanColor] colorWithAlphaComponent:0.18]}];
            self.memValueField.keyboardType = UIKeyboardTypeDefault;
        } else {
            self.memValueField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:VL(@"Mem_InputValue") attributes:@{NSForegroundColorAttributeName: [[UIColor cyanColor] colorWithAlphaComponent:0.18]}];
            self.memValueField.keyboardType = (g_currentType == VMemDataTypeString) ? UIKeyboardTypeDefault : UIKeyboardTypeDecimalPad;
        }
    }
    [self rebuildMemToolbar];
}

- (void)memTypeChanged:(UISegmentedControl *)seg {
    NSArray *typeMap = @[@(VMemDataTypeI8), @(VMemDataTypeI16), @(VMemDataTypeI32), @(VMemDataTypeI64),
                         @(VMemDataTypeU8), @(VMemDataTypeU16), @(VMemDataTypeU32), @(VMemDataTypeU64)];
    NSInteger idx = seg.selectedSegmentIndex;
    if (idx >= 0 && idx < (NSInteger)typeMap.count) {
        g_currentType = (VMemDataType)[typeMap[idx] integerValue];
        self.memTypeSeg2.selectedSegmentIndex = UISegmentedControlNoSegment;
        [self syncMemoryTypeSegmentsFromGlobalType];
        [self updateMemUIForMode];
    }
}

- (void)memType2Changed:(UISegmentedControl *)seg {
    NSArray *typeMap = @[@(VMemDataTypeF32), @(VMemDataTypeF64), @(VMemDataTypeString)];
    NSInteger idx = seg.selectedSegmentIndex;
    if (idx >= 0 && idx < (NSInteger)typeMap.count) {
        g_currentType = (VMemDataType)[typeMap[idx] integerValue];
        self.memTypeSeg.selectedSegmentIndex = UISegmentedControlNoSegment;
        if (g_currentType == VMemDataTypeString && self.memModeSeg.selectedSegmentIndex != 0) {
            self.memModeSeg.selectedSegmentIndex = 0;
        }
        [self syncMemoryTypeSegmentsFromGlobalType];
        [self updateMemUIForMode];
    }
}

- (NSInteger)nearbyTypeSelectionIndexForCurrentType {
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

- (void)applyNearbyTypeSelectionIndex:(NSInteger)index syncSegments:(BOOL)syncSegments {
    g_currentType = VLNearbyTypeForSelection(index);

    if (!syncSegments) {
        return;
    }

    if (g_currentType == VMemDataTypeF32) {
        self.memTypeSeg.selectedSegmentIndex = UISegmentedControlNoSegment;
        self.memTypeSeg2.selectedSegmentIndex = 0;
    } else if (g_currentType == VMemDataTypeF64) {
        self.memTypeSeg.selectedSegmentIndex = UISegmentedControlNoSegment;
        self.memTypeSeg2.selectedSegmentIndex = 1;
    } else {
        self.memTypeSeg.selectedSegmentIndex = [self nearbyTypeSelectionIndexForCurrentType];
        self.memTypeSeg2.selectedSegmentIndex = UISegmentedControlNoSegment;
    }
}

- (void)syncMemoryTypeSegmentsFromGlobalType {
    if (!self.nearbyTypeSeg) return;
    self.nearbyTypeSeg.selectedSegmentIndex = [self nearbyTypeSelectionIndexForCurrentType];
}

- (void)nearbyTypeChanged:(UISegmentedControl *)seg {
    if (seg.selectedSegmentIndex == UISegmentedControlNoSegment) return;
    [self applyNearbyTypeSelectionIndex:seg.selectedSegmentIndex syncSegments:YES];
    [self updateMemUIForMode];
}


- (void)rebuildMemToolbar {
    for (UIView *v in self.memToolbar.subviews) [v removeFromSuperview];

    CGFloat w = self.memToolbar.bounds.size.width;
    CGFloat h = self.memToolbar.bounds.size.height;
    NSInteger mode = self.memModeSeg.selectedSegmentIndex;
    BOOL isFuzzy = (mode == 1);

    NSString *searchTitle = self.memIsNextScan ? VL(@"Mem_Next") : VL(@"Mem_Search");
    if (isFuzzy && !self.memIsNextScan) searchTitle = VL(@"Mem_Search");

    if (isFuzzy) {
        CGFloat btnW = (w - 6) / 2;
        UIButton *searchBtn = [self createSmallBtn:searchTitle frame:CGRectMake(0, 0, btnW, h)];
        [searchBtn addTarget:self action:@selector(doMemSearch) forControlEvents:UIControlEventTouchUpInside];
        [self.memToolbar addSubview:searchBtn];

        UIButton *resetBtn = [self createSmallBtn:VL(@"Mem_Reset") frame:CGRectMake(btnW + 6, 0, btnW, h)];
        resetBtn.layer.borderColor = [[UIColor orangeColor] colorWithAlphaComponent:0.5].CGColor;
        [resetBtn setTitleColor:[[UIColor orangeColor] colorWithAlphaComponent:0.8] forState:UIControlStateNormal];
        resetBtn.backgroundColor = [[UIColor orangeColor] colorWithAlphaComponent:0.05];
        [resetBtn addTarget:self action:@selector(doMemReset) forControlEvents:UIControlEventTouchUpInside];
        [self.memToolbar addSubview:resetBtn];
    } else {
        CGFloat btnW = (w - 12) / 3;
        UIButton *searchBtn = [self createSmallBtn:searchTitle frame:CGRectMake(0, 0, btnW, h)];
        [searchBtn addTarget:self action:@selector(doMemSearch) forControlEvents:UIControlEventTouchUpInside];
        [self.memToolbar addSubview:searchBtn];

        UIButton *resetBtn = [self createSmallBtn:VL(@"Mem_Reset") frame:CGRectMake(btnW + 6, 0, btnW, h)];
        resetBtn.layer.borderColor = [[UIColor orangeColor] colorWithAlphaComponent:0.5].CGColor;
        [resetBtn setTitleColor:[[UIColor orangeColor] colorWithAlphaComponent:0.8] forState:UIControlStateNormal];
        resetBtn.backgroundColor = [[UIColor orangeColor] colorWithAlphaComponent:0.05];
        [resetBtn addTarget:self action:@selector(doMemReset) forControlEvents:UIControlEventTouchUpInside];
        [self.memToolbar addSubview:resetBtn];

        UIButton *batchBtn = [self createSmallBtn:VL(@"Batch_Btn") frame:CGRectMake(btnW * 2 + 12, 0, btnW, h)];
        [batchBtn addTarget:self action:@selector(doBatch) forControlEvents:UIControlEventTouchUpInside];
        [self.memToolbar addSubview:batchBtn];
    }
}


- (void)doMemSearch {
    if (self.memIsSearching) return;

    VMemSearchMode mode = (VMemSearchMode)self.memModeSeg.selectedSegmentIndex;

    if (mode == VMemSearchModeFuzzy && !self.memIsNextScan) {
        [self doFuzzyFirstSearch];
        return;
    }
    if (mode == VMemSearchModeFuzzy && self.memIsNextScan) {
        [self doFuzzyNextScan];
        return;
    }

    NSString *val = self.memValueField.text;
    if (val.length == 0) { self.memConsoleLabel.text = VL(@"Mem_InputRequired"); return; }

    if ([val containsString:@";"] || [val containsString:@"::"]) {
        mode = VMemSearchModeGroup;
    }

    // 自动检测范围搜索 (90~100 或 90-100)
    BOOL isRangeSearch = NO;
    NSString *rangeVal = val;
    if (mode != VMemSearchModeGroup) {
        if ([val containsString:@"~"]) {
            NSArray *parts = [val componentsSeparatedByString:@"~"];
            if (parts.count == 2 && [parts[0] length] > 0 && [parts[1] length] > 0) {
                rangeVal = [NSString stringWithFormat:@"%@,%@", parts[0], parts[1]];
                isRangeSearch = YES;
            }
        }
        if (!isRangeSearch && [val containsString:@"-"]) {
            NSRange dashRange = [val rangeOfString:@"-" options:0 range:NSMakeRange(1, val.length - 1)];
            if (dashRange.location != NSNotFound) {
                NSString *left = [val substringToIndex:dashRange.location];
                NSString *right = [val substringFromIndex:dashRange.location + 1];
                if (left.length > 0 && right.length > 0) {
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
            self.memConsoleLabel.text = [NSString stringWithFormat:@"ℹ️ %@", VL(@"Mem_BetweenHint")];
        }
    }

    // Validate numeric input for non-String/non-Group types
    if (!self.memIsNextScan && g_currentType != VMemDataTypeString && mode != VMemSearchModeGroup) {
        NSString *cleaned = [val stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (isRangeSearch) {
            // Range: validate both parts from rangeVal (format: "num,num")
            NSArray *rangeParts = [rangeVal componentsSeparatedByString:@","];
            NSRegularExpression *numRx = [NSRegularExpression regularExpressionWithPattern:@"^-?\\d+\\.?\\d*$" options:0 error:nil];
            for (NSString *rp in rangeParts) {
                NSString *t = [rp stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (t.length == 0 || [numRx numberOfMatchesInString:t options:0 range:NSMakeRange(0, t.length)] == 0) {
                    self.memConsoleLabel.text = VL(@"Err_Range_Invalid");
                    return;
                }
            }
        } else {
            // Exact: validate single value
            NSRegularExpression *numRx = [NSRegularExpression regularExpressionWithPattern:@"^-?\\d+\\.?\\d*$" options:0 error:nil];
            if ([numRx numberOfMatchesInString:cleaned options:0 range:NSMakeRange(0, cleaned.length)] == 0) {
                self.memConsoleLabel.text = VL(@"Err_Not_Numeric");
                return;
            }
        }
    }

    [self.memValueField resignFirstResponder];
    self.memIsSearching = YES;
    self.memConsoleLabel.text = VL(@"Mem_Searching");

    if (self.memIsNextScan && [VMemEngine shared].resultCount > 0) {
        [[VMemEngine shared] nextScanWithValue:val type:g_currentType filterMode:(VMemFilterMode)100 completion:^(NSUInteger count, NSString *msg) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.memIsSearching = NO;
                self.memConsoleLabel.text = [NSString stringWithFormat:@"%@ %lu", VL(@"Mem_Found"), (unsigned long)count];
                if (count > 0) {
                    NSString *detail = [NSString stringWithFormat:@"%@ %@", VLPanelTimelineTypeName(g_currentType), val ?: @""];
                    VLPanelCaptureTimeline(VLPanelTimelineModeTitle(mode), detail, g_currentType);
                }
                [self refreshMemResults];
                [self feedbackForSuccess:(count > 0)];
            });
        }];
    } else {
        NSString *searchVal = isRangeSearch ? rangeVal : val;
        [[VMemEngine shared] scanWithMode:mode value:searchVal type:g_currentType completion:^(NSUInteger count, NSString *msg) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.memIsSearching = NO;
                self.memIsNextScan = YES;
                self.memIsFirstSearch = NO;
                self.memConsoleLabel.text = [NSString stringWithFormat:@"%@ %lu", VL(@"Mem_Found"), (unsigned long)count];
                if (count > 0) {
                    NSString *detail = [NSString stringWithFormat:@"%@ %@", VLPanelTimelineTypeName(g_currentType), searchVal ?: @""];
                    VLPanelCaptureTimeline(VLPanelTimelineModeTitle(mode), detail, g_currentType);
                }
                [self updateMemUIForMode];
                [self refreshMemResults];
                [self feedbackForSuccess:(count > 0)];
            });
        }];
    }
}

- (void)doFuzzyFirstSearch {
    self.memIsSearching = YES;
    self.memConsoleLabel.text = VL(@"Mem_Searching");

    [[VMemEngine shared] fastFuzzyInitWithCompletion:^(BOOL success, NSString *msg, NSUInteger addressCount) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.memIsSearching = NO;
            if (success) {
                self.memIsNextScan = YES;
                self.memIsFirstSearch = YES;
                NSString *countStr;
                if (addressCount >= 100000000) countStr = [NSString stringWithFormat:@"%.1f亿", addressCount / 100000000.0];
                else if (addressCount >= 10000) countStr = [NSString stringWithFormat:@"%.1f万", addressCount / 10000.0];
                else countStr = [NSString stringWithFormat:@"%lu", (unsigned long)addressCount];
                self.memConsoleLabel.text = [NSString stringWithFormat:@"%@ %@", VL(@"Mem_Found"), countStr];
                [self updateMemUIForMode];
            } else {
                self.memConsoleLabel.text = msg ?: VL(@"Mem_Error");
            }
            [self feedbackForSuccess:success];
        });
    }];
}


- (void)doFuzzyNextScan {
    NSInteger fuzzyIdx = self.memFuzzyRow.selectedSegmentIndex;
    if (fuzzyIdx == UISegmentedControlNoSegment) {
        self.memConsoleLabel.text = VL(@"Fuz_Select_Mode");
        return;
    }

    VMemFilterMode modes[] = {VMemFilterModeIncreased, VMemFilterModeDecreased, VMemFilterModeUnchanged, VMemFilterModeChanged};
    VMemFilterMode filterMode = modes[fuzzyIdx];

    self.memIsSearching = YES;
    self.memConsoleLabel.text = VL(@"Mem_Filtering");

    [[VMemEngine shared] fastFuzzyFilterWithMode:filterMode type:g_currentType completion:^(NSUInteger count, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.memIsSearching = NO;
            self.memIsFirstSearch = NO;
            self.memConsoleLabel.text = [NSString stringWithFormat:@"%@ %lu", VL(@"Mem_Found"), (unsigned long)count];
            if (count > 0) {
                VLPanelCaptureTimeline(VLPanelTimelineFilterTitle(filterMode), VLPanelTimelineTypeName(g_currentType), g_currentType);
            }
            [self updateMemUIForMode];
            [self refreshMemResults];
            [self feedbackForSuccess:(count > 0)];
        });
    }];
}

- (void)doMemReset {
    [[VMemEngine shared] clearResults];
    [[VMemEngine shared] clearFastFuzzySnapshot];
    self.memIsNextScan = NO;
    self.memIsFirstSearch = YES;
    self.memFuzzyRow.selectedSegmentIndex = UISegmentedControlNoSegment;
    [self updateMemUIForMode];
    self.memConsoleLabel.text = VL(@"Mem_Ready");
    [self refreshMemResults];
}

- (void)doNearbySearch {
    NSString *val = self.nearbyValueField.text;
    NSString *rangeStr = self.nearbyRangeField.text;
    if (val.length == 0) { showToast(VL(@"Mem_InputRequired")); return; }
    [self applyNearbyTypeSelectionIndex:self.nearbyTypeSeg.selectedSegmentIndex syncSegments:YES];

    uint64_t range = rangeStr.length > 0 ? strtoull([rangeStr UTF8String], NULL, 10) : 512;
    if (range == 0) range = 512;

    NSUInteger total = [VMemEngine shared].resultCount;
    if (total == 0) { showToast(VL(@"Mem_NoResults")); return; }

    self.memConsoleLabel.text = VL(@"Mem_Searching");

    [[VMemEngine shared] scanNearbyWithValue:val type:g_currentType range:range completion:^(NSUInteger count, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.memConsoleLabel.text = [NSString stringWithFormat:@"%@ %lu", VL(@"Mem_Found"), (unsigned long)count];
            self.memIsNextScan = YES;
            self.memIsFirstSearch = NO;
            if (count > 0) {
                NSString *detail = [NSString stringWithFormat:@"%@ %@ ±%llu", VLPanelTimelineTypeName(g_currentType), val ?: @"", range];
                VLPanelCaptureTimeline(VL(@"Nearby_Btn"), detail, g_currentType);
            }
            [self updateMemUIForMode];
            [self refreshMemResults];
            [self feedbackForSuccess:(count > 0)];
        });
    }];
}

#pragma mark - Batch Operations

- (void)doBatch {
    NSUInteger count = [VMemEngine shared].resultCount;
    if (count == 0) { self.memConsoleLabel.text = VL(@"Mem_NoResults"); return; }

    UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"Batch_Btn") message:nil preferredStyle:UIAlertControllerStyleActionSheet];

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
        ac.popoverPresentationController.sourceView = self.memToolbar;
        ac.popoverPresentationController.sourceRect = self.memToolbar.bounds;
    }
    [[GetSafeWindow() rootViewController] presentViewController:ac animated:YES completion:nil];
}


- (void)showBatchModifyAlert {
    NSUInteger count = MIN([VMemEngine shared].resultCount, 100);
    NSString *hint = [NSString stringWithFormat:VL(@"Batch_Modify_Hint"), (unsigned long)count];

    UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"Batch_Modify") message:hint preferredStyle:UIAlertControllerStyleAlert];
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
        self.memConsoleLabel.text = msg;
        [self refreshMemResults];
    }]];
    [[GetSafeWindow() rootViewController] presentViewController:ac animated:YES completion:nil];
}

- (void)copyAddresses {
    NSUInteger count = MIN([VMemEngine shared].resultCount, 100);
    NSMutableString *addresses = [NSMutableString string];
    for (NSUInteger i = 0; i < count; i++) {
        VMemResultItem *item = [[VMemEngine shared] getResultAtIndex:i type:g_currentType];
        if (item) [addresses appendFormat:@"0x%llX\n", item.address];
    }
    if (addresses.length > 0) {
        [UIPasteboard generalPasteboard].string = addresses;
        NSString *msg = [NSString stringWithFormat:VL(@"Batch_Copied"), (unsigned long)count];
        self.memConsoleLabel.text = msg;
    }
}

- (void)refreshMemResults {
    self.memResultPage = 0;
    [self.memResultsTable reloadData];
    [self updateMemPager];
    self.memResultsTable.backgroundView.hidden = ([VMemEngine shared].resultCount > 0);
    [self updateMemMultiSelectButtonTitle];
}

- (void)manualRefreshMemResults {
    [self refreshMemResults];
    [self refreshBrowserRowsFromMemory];
    showToast(VL(@"Refresh_Done"));
}

- (void)updateMemPager {
    NSUInteger total = [VMemEngine shared].resultCount;
    NSInteger totalPages = (total + kPageSize - 1) / kPageSize;
    if (totalPages == 0) totalPages = 1;
    self.memPageLabel.text = [NSString stringWithFormat:@"%ld / %ld", (long)(self.memResultPage + 1), (long)totalPages];
    self.memResultsCountLabel.text = [NSString stringWithFormat:@"(%lu)", (unsigned long)total];
}

- (void)updateMemMultiSelectButtonTitle {
    if (!self.memSelectButton) return;
    NSString *title = self.memMultiSelectMode
        ? [NSString stringWithFormat:@"%@(%lu)", VL(@"Batch_Action"), (unsigned long)self.multiSelectedAddresses.count]
        : VL(@"Batch_Select");
    [self.memSelectButton setTitle:title forState:UIControlStateNormal];
}

- (void)memPrevPage {
    if (self.memResultPage > 0) { self.memResultPage--; [self.memResultsTable reloadData]; [self updateMemPager]; }
}

- (void)memNextPage {
    NSUInteger total = [VMemEngine shared].resultCount;
    NSInteger totalPages = (total + kPageSize - 1) / kPageSize;
    if (self.memResultPage < totalPages - 1) { self.memResultPage++; [self.memResultsTable reloadData]; [self updateMemPager]; }
}

- (void)feedbackForSuccess:(BOOL)success {
    if (success) {
        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [fb prepare]; [fb impactOccurred];
    } else {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }
}

- (NSString *)shortNameForType:(VMemDataType)t {
    switch (t) {
        case VMemDataTypeI8:  return @"i8";  case VMemDataTypeI16: return @"i16";
        case VMemDataTypeI32: return @"i32"; case VMemDataTypeI64: return @"i64";
        case VMemDataTypeU8:  return @"u8";  case VMemDataTypeU16: return @"u16";
        case VMemDataTypeU32: return @"u32"; case VMemDataTypeU64: return @"u64";
        case VMemDataTypeF32: return @"f32"; case VMemDataTypeF64: return @"f64";
        case VMemDataTypeString: return @"str";
        default: return @"?";
    }
}


#pragma mark - Memory Result Cell

- (UITableViewCell *)memResultCellForIndex:(NSInteger)row {
    NSUInteger idx = self.memResultPage * kPageSize + row;
    VMemResultItem *item = [[VMemEngine shared] getResultAtIndex:idx type:g_currentType];
    VMemDataType displayType = item ? item.type : g_currentType;
    BOOL isStringType = (displayType == VMemDataTypeString);

    static NSString *cellId = @"MemResCell";
    UITableViewCell *cell = [self.memResultsTable dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.025];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.layer.cornerRadius = 6;
        cell.layer.borderWidth = 0.5;
        cell.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.08].CGColor;

        UILabel *addrLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        addrLabel.font = [UIFont fontWithName:@"Menlo" size:9];
        addrLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.5];
        addrLabel.tag = 101;
        [cell.contentView addSubview:addrLabel];

        UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        valueLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:11];
        valueLabel.textColor = [UIColor cyanColor];
        valueLabel.tag = 102;
        [cell.contentView addSubview:valueLabel];

        UIButton *lockBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        lockBtn.titleLabel.font = [UIFont systemFontOfSize:9];
        lockBtn.tag = 103;
        [cell.contentView addSubview:lockBtn];

        UIButton *browseBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        browseBtn.titleLabel.font = [UIFont systemFontOfSize:9];
        browseBtn.tag = 104;
        [cell.contentView addSubview:browseBtn];

        UIButton *watchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        watchBtn.titleLabel.font = [UIFont systemFontOfSize:9];
        watchBtn.tag = 105;
        [cell.contentView addSubview:watchBtn];
    }

    UILabel *addrLabel = [cell.contentView viewWithTag:101];
    UILabel *valueLabel = [cell.contentView viewWithTag:102];
    UIButton *lockBtn = [cell.contentView viewWithTag:103];
    UIButton *browseBtn = [cell.contentView viewWithTag:104];
    UIButton *watchBtn = [cell.contentView viewWithTag:105];

    CGFloat cw = self.memResultsTable.bounds.size.width - 4;

        if (item) {
            NSString *freshVal = [[VMemEngine shared] readAddress:item.address type:displayType];
            if (freshVal) item.valueStr = freshVal;

        addrLabel.text = [NSString stringWithFormat:@"0x%llX", item.address];
        NSString *typePrefix = [self shortNameForType:displayType];
        valueLabel.text = [NSString stringWithFormat:@"%@:%@", typePrefix, item.valueStr ?: @"--"];
        BOOL locked = (self.memLockedItems[@(item.address)] != nil);
        BOOL selected = self.memMultiSelectMode && [self.multiSelectedAddresses containsObject:@(item.address)];
        if (selected) {
            cell.backgroundColor = [[UIColor systemYellowColor] colorWithAlphaComponent:0.16];
        } else {
            cell.backgroundColor = locked ? [[UIColor cyanColor] colorWithAlphaComponent:0.1] : [[UIColor cyanColor] colorWithAlphaComponent:0.025];
        }

        if (isStringType) {
            addrLabel.frame = CGRectMake(8, 6, cw - 16, 16);
            valueLabel.frame = CGRectMake(8, 24, cw - 16, 20);
            valueLabel.lineBreakMode = NSLineBreakByTruncatingTail;
            lockBtn.hidden = YES; browseBtn.hidden = YES; watchBtn.hidden = YES;
        } else {
            CGFloat btnW = 36;
            BOOL hasWatch = [VLDebugEngine isAvailable];
            CGFloat btnsW = hasWatch ? (btnW * 3 + 6) : (btnW * 2 + 3);

            addrLabel.frame = CGRectMake(8, 6, cw - btnsW - 16, 16);
            valueLabel.frame = CGRectMake(8, 24, cw - btnsW - 16, 20);
            valueLabel.lineBreakMode = NSLineBreakByTruncatingTail;

            CGFloat bx = cw - btnsW - 4;
            lockBtn.hidden = NO;
            lockBtn.frame = CGRectMake(bx, 10, btnW, 30);
            [lockBtn setTitle:locked ? VL(@"UI_Locked") : VL(@"UI_Unlocked") forState:UIControlStateNormal];
            [lockBtn setTitleColor:locked ? [UIColor cyanColor] : [[UIColor cyanColor] colorWithAlphaComponent:0.5] forState:UIControlStateNormal];
            objc_setAssociatedObject(lockBtn, "addr", @(item.address), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [lockBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
            [lockBtn addTarget:self action:@selector(onMemResultLock:) forControlEvents:UIControlEventTouchUpInside];

            browseBtn.hidden = NO;
            browseBtn.frame = CGRectMake(bx + btnW + 3, 10, btnW, 30);
            [browseBtn setTitle:VL(@"Mem_Browser") forState:UIControlStateNormal];
            [browseBtn setTitleColor:[[UIColor cyanColor] colorWithAlphaComponent:0.6] forState:UIControlStateNormal];
            objc_setAssociatedObject(browseBtn, "addr", @(item.address), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [browseBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
            [browseBtn addTarget:self action:@selector(onMemResultBrowse:) forControlEvents:UIControlEventTouchUpInside];

            if (hasWatch) {
                watchBtn.hidden = NO;
                watchBtn.frame = CGRectMake(bx + btnW * 2 + 6, 10, btnW, 30);
                [watchBtn setTitle:VL(@"Watch_Btn") forState:UIControlStateNormal];
                [watchBtn setTitleColor:[[UIColor cyanColor] colorWithAlphaComponent:0.6] forState:UIControlStateNormal];
                objc_setAssociatedObject(watchBtn, "addr", @(item.address), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [watchBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
                [watchBtn addTarget:self action:@selector(onMemResultWatch:) forControlEvents:UIControlEventTouchUpInside];
            } else { watchBtn.hidden = YES; }
        }
    } else {
        addrLabel.text = @"--"; addrLabel.frame = CGRectMake(8, 6, cw - 16, 16);
        valueLabel.text = @"--"; valueLabel.frame = CGRectMake(8, 24, cw - 16, 20);
        lockBtn.hidden = YES; browseBtn.hidden = YES; watchBtn.hidden = YES;
    }
    return cell;
}

- (void)handleMemResultLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    NSIndexPath *indexPath = [self.memResultsTable indexPathForRowAtPoint:[gesture locationInView:self.memResultsTable]];
    if (!indexPath) return;

    [self enterMemoryMultiSelectMode];
    [self toggleMemorySelectionAtIndexPath:indexPath];
}

- (void)enterMemoryMultiSelectMode {
    self.memMultiSelectMode = YES;
    self.browserMultiSelectMode = NO;
    [self.multiSelectedAddresses removeAllObjects];
    [self.multiSelectedTypes removeAllObjects];
    [self updateMemMultiSelectButtonTitle];
    [self.memResultsTable reloadData];
}

- (void)exitMemoryMultiSelectMode {
    self.memMultiSelectMode = NO;
    [self.multiSelectedAddresses removeAllObjects];
    [self.multiSelectedTypes removeAllObjects];
    [self updateMemMultiSelectButtonTitle];
    [self.memResultsTable reloadData];
}

- (void)toggleMemorySelectionAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger idx = self.memResultPage * kPageSize + indexPath.row;
    VMemResultItem *item = [[VMemEngine shared] getResultAtIndex:idx type:g_currentType];
    if (!item || item.type == VMemDataTypeString) return;

    NSNumber *addrKey = @(item.address);
    if ([self.multiSelectedAddresses containsObject:addrKey]) {
        [self.multiSelectedAddresses removeObject:addrKey];
        [self.multiSelectedTypes removeObjectForKey:addrKey];
    } else {
        [self.multiSelectedAddresses addObject:addrKey];
        self.multiSelectedTypes[addrKey] = @(item.type);
    }
    [self updateMemMultiSelectButtonTitle];
    [self.memResultsTable reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)onMemSelectButtonTapped {
    if (!self.memMultiSelectMode) {
        [self enterMemoryMultiSelectMode];
        return;
    }
    [self showSelectedBatchActionsForBrowser:NO];
}

- (NSArray<NSNumber *> *)sortedSelectedAddresses {
    return [[self.multiSelectedAddresses allObjects] sortedArrayUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
        return [a compare:b];
    }];
}

- (void)showSelectedBatchActionsForBrowser:(BOOL)isBrowser {
    if (self.multiSelectedAddresses.count == 0) {
        showToast(VL(@"Batch_NoSelection"));
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:VL(@"Batch_Selected_Count"), (unsigned long)self.multiSelectedAddresses.count]
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:VL(@"Batch_Fixed") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self showSelectedBatchInputWithMode:0 browser:isBrowser];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:VL(@"Batch_Increment") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self showSelectedBatchInputWithMode:1 browser:isBrowser];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:VL(@"Batch_Copy") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self copySelectedAddressesAndExitBrowser:isBrowser];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:VL(@"Batch_Select_All") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        if (isBrowser) [self selectAllVisibleBrowserRows];
        else [self selectAllVisibleMemResults];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:VL(@"Batch_Exit_Select") style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) {
        if (isBrowser) [self exitBrowserMultiSelectMode];
        else [self exitMemoryMultiSelectMode];
    }]];
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = isBrowser ? self.browserTable : self.memResultsTable;
        sheet.popoverPresentationController.sourceRect = (isBrowser ? self.browserTable : self.memResultsTable).bounds;
    }
    [[GetSafeWindow() rootViewController] presentViewController:sheet animated:YES completion:nil];
}

- (void)showSelectedBatchInputWithMode:(NSInteger)mode browser:(BOOL)isBrowser {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:(mode == 0 ? VL(@"Batch_Fixed") : VL(@"Batch_Increment"))
                                                                   message:[NSString stringWithFormat:VL(@"Batch_Selected_Count"), (unsigned long)self.multiSelectedAddresses.count]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = (mode == 0) ? VL(@"Mem_NewValue") : VL(@"Batch_Start_Value");
        tf.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:VL(@"Mem_Write") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *input = alert.textFields.firstObject.text;
        if (input.length == 0) return;
        [self executeSelectedBatchWrite:input mode:mode browser:isBrowser];
    }]];
    [[GetSafeWindow() rootViewController] presentViewController:alert animated:YES completion:nil];
}

- (NSString *)batchValueFromInput:(NSString *)input type:(VMemDataType)type offset:(NSUInteger)offset mode:(NSInteger)mode {
    if (mode == 0) return input;
    if (type == VMemDataTypeF32 || type == VMemDataTypeF64) {
        return [NSString stringWithFormat:@"%f", [input doubleValue] + (double)offset];
    }
    return [NSString stringWithFormat:@"%lld", [input longLongValue] + (long long)offset];
}

- (void)executeSelectedBatchWrite:(NSString *)input mode:(NSInteger)mode browser:(BOOL)isBrowser {
    NSArray<NSNumber *> *addresses = [self sortedSelectedAddresses];
    NSUInteger successCount = 0;
    VMemEngine *engine = [VMemEngine shared];

    for (NSUInteger i = 0; i < addresses.count; i++) {
        NSNumber *addrKey = addresses[i];
        VMemDataType type = (VMemDataType)[(self.multiSelectedTypes[addrKey] ?: @(g_currentType)) integerValue];
        NSString *writeValue = [self batchValueFromInput:input type:type offset:i mode:mode];
        if ([engine writeAddress:[addrKey unsignedLongLongValue] value:writeValue type:type]) {
            successCount++;
            if (self.memLockedItems[addrKey]) {
                self.memLockedItems[addrKey] = @{@"value": writeValue, @"type": @(type)};
            }
            for (VLPanelMemItem *mi in self.tbMemResults) {
                if (mi.address == [addrKey unsignedLongLongValue]) {
                    mi.currentValue = writeValue;
                    if (mi.isLocked) mi.lockValue = writeValue;
                }
            }
        }
    }

    showToast([NSString stringWithFormat:VL(@"Batch_Modified"), (unsigned long)successCount]);
    [self refreshMemResults];
    [self refreshBrowserRowsFromMemory];
    if (isBrowser) [self exitBrowserMultiSelectMode];
    else [self exitMemoryMultiSelectMode];
    if (self.currentSubTab == VLToolboxSubLock) [self.tbTable reloadData];
}

- (void)selectAllVisibleMemResults {
    NSUInteger total = [VMemEngine shared].resultCount;
    NSUInteger start = self.memResultPage * kPageSize;
    NSUInteger end = MIN(total, start + kPageSize);
    for (NSUInteger i = start; i < end; i++) {
        VMemResultItem *item = [[VMemEngine shared] getResultAtIndex:i type:g_currentType];
        if (!item || item.type == VMemDataTypeString) continue;
        NSNumber *addrKey = @(item.address);
        [self.multiSelectedAddresses addObject:addrKey];
        self.multiSelectedTypes[addrKey] = @(item.type);
    }
    [self updateMemMultiSelectButtonTitle];
    [self.memResultsTable reloadData];
}

- (void)copySelectedAddressesAndExitBrowser:(BOOL)isBrowser {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSNumber *addrNum in [self sortedSelectedAddresses]) {
        [lines addObject:[NSString stringWithFormat:@"0x%llX", [addrNum unsignedLongLongValue]]];
    }
    [UIPasteboard generalPasteboard].string = [lines componentsJoinedByString:@"\n"];
    showToast([NSString stringWithFormat:VL(@"Batch_Copied"), (unsigned long)lines.count]);
    if (isBrowser) [self exitBrowserMultiSelectMode];
    else [self exitMemoryMultiSelectMode];
}


#pragma mark - Memory Result Actions

- (void)onMemResultLock:(UIButton *)sender {
    NSNumber *addrNum = objc_getAssociatedObject(sender, "addr");
    if (!addrNum) return;
    uint64_t address = [addrNum unsignedLongLongValue];
    NSNumber *addrKey = @(address);

    if (self.memLockedItems[addrKey]) {
        [self.memLockedItems removeObjectForKey:addrKey];
        for (NSInteger i = (NSInteger)self.tbMemResults.count - 1; i >= 0; i--) {
            VLPanelMemItem *mi = self.tbMemResults[i];
            if (mi.address == address) { [self.tbMemResults removeObjectAtIndex:i]; break; }
        }
        showToast(VL(@"Msg_Unlocked"));
    } else {
        VMemResultItem *item = nil;
        NSUInteger total = [VMemEngine shared].resultCount;
        for (NSUInteger i = 0; i < MIN(total, 200); i++) {
            VMemResultItem *r = [[VMemEngine shared] getResultAtIndex:i type:g_currentType];
            if (r && r.address == address) { item = r; break; }
        }
        NSString *val = item ? (item.valueStr ?: @"0") : @"0";
        VMemDataType itemType = item ? item.type : g_currentType;
        self.memLockedItems[addrKey] = @{@"value": val, @"type": @(itemType)};
        BOOL exists = NO;
        for (VLPanelMemItem *mi in self.tbMemResults) {
            if (mi.address == address) { mi.isLocked = YES; mi.lockValue = val; exists = YES; break; }
        }
        if (!exists) {
            VLPanelMemItem *mi = [[VLPanelMemItem alloc] init];
            mi.address = address; mi.dataType = itemType;
            mi.currentValue = val; mi.isLocked = YES; mi.lockValue = val;
            [self.tbMemResults addObject:mi];
        }
        showToast(VL(@"Msg_Locked"));
    }
    [self.memResultsTable reloadData];
    if (self.currentSubTab == VLToolboxSubLock) [self.tbTable reloadData];
}

- (void)onMemResultBrowse:(UIButton *)sender {
    NSNumber *addrNum = objc_getAssociatedObject(sender, "addr");
    if (!addrNum) return;
    [self navigateBrowserToAddress:[addrNum unsignedLongLongValue]];
}

- (void)onMemResultWatch:(UIButton *)sender {
    NSNumber *addrNum = objc_getAssociatedObject(sender, "addr");
    if (!addrNum) return;
    uint64_t address = [addrNum unsignedLongLongValue];
    [VLWatchOverlay addWatchForAddress:address];
    self.currentSubTab = VLToolboxSubWatch;
    self.watchSelectedSlot = -1;
    [self switchToTab:VLMainTabToolbox animated:YES];
    [self updateSubTabHighlight];
    self.tbTable.hidden = YES;
    [self showWatchFusionView];
    [self updateTbPager];
    [self rebuildTbBottomButtons];
}

- (void)showWriteValueAlert:(VMemResultItem *)item {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"0x%llX", item.address] message:nil preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = item.valueStr;
        tf.keyboardType = UIKeyboardTypeDecimalPad;
        tf.placeholder = VL(@"Mem_NewValue");
    }];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Mem_Write") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *newVal = ac.textFields.firstObject.text;
        if (newVal.length > 0) {
            BOOL ok = [[VMemEngine shared] writeAddress:item.address value:newVal type:item.type];
            if (ok) {
                showToast(VL(@"Mem_WriteOK"));
                NSString *freshVal = [[VMemEngine shared] readAddress:item.address type:item.type] ?: newVal;
                item.valueStr = freshVal;
                if (self.memLockedItems[@(item.address)]) {
                    self.memLockedItems[@(item.address)] = @{@"value": freshVal, @"type": @(item.type)};
                }
                for (VLPanelMemItem *mi in self.tbMemResults) {
                    if (mi.address == item.address) {
                        mi.currentValue = freshVal;
                        if (mi.isLocked) mi.lockValue = freshVal;
                    }
                }
                [self.memResultsTable reloadData];
                [self refreshBrowserRowsFromMemory];
                if (self.currentSubTab == VLToolboxSubLock) {
                    [self.tbTable reloadData];
                }
            } else { showToast(VL(@"Mem_WriteFail")); }
        }
    }]];
    [[GetSafeWindow() rootViewController] presentViewController:ac animated:YES completion:nil];
}

@end
