// ChartBrowse.m — 「谱面查询」默认页：默认 / 类别 / 难度 / 版本 / 达成率
#import "ChartBrowse.h"
#import "ChartDb.h"
#import "B50Core.h"
#import "B50Image.h"
#import <math.h>

static NSArray *ModeNames(void)
{
    return @[@"默认", @"类别", @"难度", @"版本", @"达成率"];
}

/// 达成率分档：名称 + 下界（含）
static NSArray *RankTiers(void)
{
    return @[@"D", @"C", @"B", @"BB", @"BBB", @"A", @"AA", @"AAA",
             @"S", @"S+", @"SS", @"SS+", @"SSS", @"SSS+"];
}

static double RankLower(NSString *name)
{
    if ([name isEqualToString:@"SSS+"]) return 100.5;
    if ([name isEqualToString:@"SSS"]) return 100.0;
    if ([name isEqualToString:@"SS+"]) return 99.5;
    if ([name isEqualToString:@"SS"]) return 99.0;
    if ([name isEqualToString:@"S+"]) return 98.0;
    if ([name isEqualToString:@"S"]) return 97.0;
    if ([name isEqualToString:@"AAA"]) return 94.0;
    if ([name isEqualToString:@"AA"]) return 90.0;
    if ([name isEqualToString:@"A"]) return 80.0;
    if ([name isEqualToString:@"BBB"]) return 75.0;
    if ([name isEqualToString:@"BB"]) return 70.0;
    if ([name isEqualToString:@"B"]) return 60.0;
    if ([name isEqualToString:@"C"]) return 50.0;
    return 0.0;
}

static NSString *RankRangeText(NSString *name)
{
    double lo = RankLower(name);
    if ([name isEqualToString:@"SSS+"]) return @"100.5000% 以上";
    double hi = lo + 5.0;
    if ([name isEqualToString:@"SSS"]) hi = 100.4999;
    else if ([name isEqualToString:@"SS+"]) hi = 99.9999;
    else if ([name isEqualToString:@"SS"]) hi = 99.4999;
    else if ([name isEqualToString:@"S+"]) hi = 98.9999;
    else if ([name isEqualToString:@"S"]) hi = 97.9999;
    else if ([name isEqualToString:@"AAA"]) hi = 96.9999;
    else if ([name isEqualToString:@"AA"]) hi = 93.9999;
    else if ([name isEqualToString:@"A"]) hi = 89.9999;
    else if ([name isEqualToString:@"BBB"]) hi = 79.9999;
    else if ([name isEqualToString:@"BB"]) hi = 74.9999;
    else if ([name isEqualToString:@"B"]) hi = 69.9999;
    else if ([name isEqualToString:@"C"]) hi = 59.9999;
    else hi = 49.9999;
    return [NSString stringWithFormat:@"%.4f%% – %.4f%%", lo, hi];
}

static NSString *RankOf(double rate)
{
    static NSArray *tiers;
    if (!tiers) tiers = [[RankTiers() reverseObjectEnumerator] allObjects];   // 从高到低
    for (NSString *t in tiers) {
        if (rate >= RankLower(t)) return t;
        if ([t isEqualToString:@"D"]) return @"D";
    }
    return @"D";
}

/// 难度分档：13.7 以上算 13+
static NSString *LevelBucket(double v)
{
    int base = (int)floor(v);
    if (base < 0) base = 0;
    if (base > 15) base = 15;
    BOOL plus = (v - base) >= 0.65;
    return [NSString stringWithFormat:@"Lv%d%@", base, plus ? @"+" : @""];
}

static NSString *CleanGenre(NSString *g)
{
    if (![g isKindOfClass:[NSString class]] || g.length == 0) return @"其他";
    return [g stringByReplacingOccurrencesOfString:@"＆" withString:@""];
}

static NSString *DiffNameForBrowse(NSInteger d)
{
    switch (d) {
        case 0: return @"BASIC";
        case 1: return @"ADVANCED";
        case 2: return @"EXPERT";
        case 3: return @"MASTER";
        case 4: return @"Re:MASTER";
        default: return @"MASTER";
    }
}

#pragma mark - 成绩表（从 Documents/cache 读一次）

static NSDictionary *BRRateMap(void)
{
    static NSDictionary *map;
    static BOOL tried = NO;
    if (tried) return map;
    tried = YES;

    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/cache"];
    NSError *err = nil;
    NSDictionary *cache = [ADXB50 readCacheAt:path error:&err];
    NSMutableDictionary *m = [NSMutableDictionary dictionary];

    NSDictionary *lm = cache[@"level_metadata"];
    if ([lm isKindOfClass:[NSDictionary class]]) {
        for (NSString *key in lm) {
            NSDictionary *s = lm[key];
            if (![s isKindOfClass:[NSDictionary class]]) continue;
            NSString *title = s[@"title"];
            if (![title isKindOfClass:[NSString class]]) continue;
            NSArray *diffs = s[@"difficulties"];
            if (![diffs isKindOfClass:[NSArray class]]) continue;
            for (NSDictionary *d in diffs) {
                if (![d isKindOfClass:[NSDictionary class]]) continue;
                int did = [d[@"id"] intValue] - 2;
                NSDictionary *st = d[@"stats"];
                if (![st isKindOfClass:[NSDictionary class]]) continue;
                double rate = [st[@"achievementRate"] doubleValue];
                if (rate <= 0) continue;
                m[[NSString stringWithFormat:@"%@|%d", title, did]] = @(rate);
            }
        }
    }
    map = m;
    return map;
}

static double BRRateOf(NSArray *song, NSArray *chart)
{
    if (!chart) return -1;
    NSString *title = song[1];
    if (![title isKindOfClass:[NSString class]]) return -1;
    int did = [chart[0] intValue];
    NSNumber *n = BRRateMap()[[NSString stringWithFormat:@"%@|%d", title, did]];
    return n ? n.doubleValue : -1;
}

#pragma mark - 单元格

@interface ADXBrowseHead : UITableViewCell
@property (nonatomic, strong) UIView *accent;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) UIImageView *chev;
- (void)setOpen:(BOOL)open;
@end

@implementation ADXBrowseHead

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = [UIColor clearColor];

    _accent = [[UIView alloc] initWithFrame:CGRectZero];
    _accent.backgroundColor = [UIColor systemBlueColor];
    _accent.layer.cornerRadius = 2;
    [self.contentView addSubview:_accent];

    _title = [[UILabel alloc] initWithFrame:CGRectZero];
    _title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    _title.textColor = [UIColor labelColor];
    [self.contentView addSubview:_title];

    _chev = [[UIImageView alloc] initWithFrame:CGRectZero];
    _chev.tintColor = [UIColor tertiaryLabelColor];
    _chev.contentMode = UIViewContentModeCenter;   // 图标按原始比例居中，避免被拉伸
    [self.contentView addSubview:_chev];
    return self;
}

- (void)setOpen:(BOOL)open
{
    _chev.image = [UIImage systemImageNamed:(open ? @"chevron.down" : @"chevron.right")
                          withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15
                                                                                            weight:UIFontWeightSemibold]];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    self.accent.frame = CGRectMake(16, (48 - 20) / 2.0, 4, 20);
    self.title.frame = CGRectMake(28, 0, w - 28 - 46, 48);
    self.chev.frame = CGRectMake(w - 38, (48 - 22) / 2.0, 22, 22);
}

@end

@interface ADXBrowseRow : UITableViewCell
@property (nonatomic, strong) UIImageView *cover;
@property (nonatomic, strong) UILabel *name;
@property (nonatomic, strong) UILabel *sub;
@property (nonatomic, assign) int songId;
@end

@implementation ADXBrowseRow

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    _cover = [[UIImageView alloc] initWithFrame:CGRectZero];
    _cover.backgroundColor = [UIColor secondarySystemBackgroundColor];
    _cover.contentMode = UIViewContentModeScaleAspectFill;
    _cover.layer.cornerRadius = 6;
    _cover.layer.masksToBounds = YES;
    [self.contentView addSubview:_cover];

    _name = [[UILabel alloc] initWithFrame:CGRectZero];
    _name.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _name.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:_name];

    _sub = [[UILabel alloc] initWithFrame:CGRectZero];
    _sub.font = [UIFont systemFontOfSize:12.5];
    _sub.textColor = [UIColor secondaryLabelColor];
    _sub.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:_sub];
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    self.cover.frame = CGRectMake(16, (58 - 40) / 2.0, 40, 40);
    self.name.frame = CGRectMake(66, 9, w - 66 - 34, 20);
    self.sub.frame = CGRectMake(66, 31, w - 66 - 34, 18);
}

@end

#pragma mark - 主视图

@interface ADXChartBrowse () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIScrollView *bar;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSArray *modeButtons;
@property (nonatomic, assign) NSInteger mode;
@property (nonatomic, strong) NSArray *sections;      // 每项 @{@"title", @"rows"}
@property (nonatomic, strong) NSMutableSet *openKeys; // "mode|title"
@property (nonatomic, strong) UIButton *favButton;
@property (nonatomic, strong) UIButton *expandButton;
@end

@implementation ADXChartBrowse

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.openKeys = [NSMutableSet set];

    self.bar = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.bar.showsHorizontalScrollIndicator = NO;
    [self addSubview:self.bar];

    NSMutableArray *btns = [NSMutableArray array];
    NSArray *names = ModeNames();
    for (NSUInteger i = 0; i < names.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        [b setTitle:names[i] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        b.tag = (NSInteger)i;
        [b addTarget:self action:@selector(modeTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.bar addSubview:b];
        [btns addObject:b];
    }
    self.modeButtons = btns;

    self.favButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.favButton setTitle:@"收藏夹" forState:UIControlStateNormal];
    self.favButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [self.favButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    self.favButton.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.favButton.layer.cornerRadius = 15;
    self.favButton.layer.borderWidth = 0.5;
    self.favButton.layer.borderColor = [UIColor separatorColor].CGColor;
    [self.favButton addTarget:self action:@selector(favTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.favButton];

    // 全部展开 / 全部折叠（纯文字，和「收藏夹」胶囊区分开）
    self.expandButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.expandButton setTitle:@"全部展开" forState:UIControlStateNormal];
    self.expandButton.titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    [self.expandButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    [self.expandButton addTarget:self action:@selector(expandAllTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.expandButton];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.rowHeight = 58;
    self.table.backgroundColor = [UIColor clearColor];
    self.table.separatorInset = UIEdgeInsetsZero;
    self.table.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self addSubview:self.table];

    [self refreshModeButtons];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self buildSections];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.table reloadData];
        });
    });
    return self;
}

- (void)reload
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self buildSections];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.table reloadData];
        });
    });
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;

    CGFloat x = 16;
    for (UIButton *b in self.modeButtons) {
        CGSize s = [b.titleLabel sizeThatFits:CGSizeMake(200, 30)];
        CGFloat bw = ceil(s.width) + 26;
        b.frame = CGRectMake(x, 6, bw, 32);
        b.layer.cornerRadius = 16;
        b.layer.masksToBounds = YES;
        x += bw + 8;
    }
    self.bar.frame = CGRectMake(0, 0, w - 82 - 80, 44);
    self.bar.contentSize = CGSizeMake(x + 8, 44);
    self.favButton.frame = CGRectMake(w - 74, 7, 66, 30);
    self.expandButton.frame = CGRectMake(w - 74 - 76, 7, 72, 30);

    self.table.frame = CGRectMake(0, 44, w, self.bounds.size.height - 44);
}

- (void)refreshModeButtons
{
    for (UIButton *b in self.modeButtons) {
        BOOL on = (b.tag == self.mode);
        b.backgroundColor = on ? [UIColor systemBlueColor] : [UIColor secondarySystemGroupedBackgroundColor];
        [b setTitleColor:(on ? [UIColor whiteColor] : [UIColor labelColor]) forState:UIControlStateNormal];
    }
}

- (void)favTapped
{
    if (self.onFavorites) self.onFavorites();
}

- (void)modeTapped:(UIButton *)b
{
    if (b.tag == self.mode) return;
    self.mode = b.tag;
    [self refreshModeButtons];
    [self buildSections];
    [self.table reloadData];
    [self refreshExpandTitle];
}

- (void)expandAllTapped
{
    if (self.mode == 0) return;

    BOOL allOpen = (self.sections.count > 0);
    for (NSDictionary *g in self.sections) {
        NSString *key = [NSString stringWithFormat:@"%ld|%@", (long)self.mode, g[@"title"]];
        if (![self.openKeys containsObject:key]) { allOpen = NO; break; }
    }

    for (NSDictionary *g in self.sections) {
        NSString *key = [NSString stringWithFormat:@"%ld|%@", (long)self.mode, g[@"title"]];
        if (allOpen) [self.openKeys removeObject:key];
        else [self.openKeys addObject:key];
    }
    [self buildSections];
    [UIView performWithoutAnimation:^{
        [self.table reloadData];
    }];
    [self refreshExpandTitle];
}

- (void)refreshExpandTitle
{
    if (self.mode == 0) { self.expandButton.hidden = YES; return; }
    self.expandButton.hidden = NO;

    BOOL allOpen = (self.sections.count > 0);
    for (NSDictionary *g in self.sections) {
        NSString *key = [NSString stringWithFormat:@"%ld|%@", (long)self.mode, g[@"title"]];
        if (![self.openKeys containsObject:key]) { allOpen = NO; break; }
    }
    [self.expandButton setTitle:(allOpen ? @"全部折叠" : @"全部展开") forState:UIControlStateNormal];
}

- (void)headerTapped:(UITapGestureRecognizer *)g
{
    UIView *v = g.view;
    NSInteger section = v.tag;
    if (section < 0 || section >= (NSInteger)self.sections.count) return;

    NSString *title = self.sections[section][@"title"];
    NSString *key = [NSString stringWithFormat:@"%ld|%@", (long)self.mode, title];
    if ([self.openKeys containsObject:key]) [self.openKeys removeObject:key];
    else [self.openKeys addObject:key];

    [self buildSections];
    [self.table reloadData];
    [self refreshExpandTitle];
}

#pragma mark - 生成数据

- (void)buildSections
{
    NSArray *songs = [ADXChartDb songs];
    NSMutableArray *out = [NSMutableArray array];

    if (self.mode == 0) {
        NSMutableArray *rows = [NSMutableArray array];
        for (NSArray *s in songs) {
            [rows addObject:@{@"song": s}];
        }
        [out addObject:@{@"title": @"", @"rows": rows}];
        self.sections = out;
        return;
    }

    if (self.mode == 1) {
        // 类别
        NSMutableDictionary *groups = [NSMutableDictionary dictionary];
        for (NSArray *s in songs) {
            NSString *g = CleanGenre([ADXChartDb jpGenreName:s]);
            NSMutableArray *arr = groups[g];
            if (!arr) { arr = [NSMutableArray array]; groups[g] = arr; }
            [arr addObject:@{@"song": s}];
        }
        NSArray *sorted = [groups.allKeys sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
        for (NSString *g in sorted) {
            [out addObject:@{@"title": [NSString stringWithFormat:@"%@（%lu）", g, (unsigned long)[groups[g] count]],
                             @"rows": groups[g]}];
        }
        self.sections = [self applyOpen:out];
        return;
    }

    if (self.mode == 2) {
        // 难度
        NSMutableDictionary *groups = [NSMutableDictionary dictionary];
        for (NSArray *s in songs) {
            NSArray *std = [ADXChartDb chartsOf:s dx:NO];
            NSArray *dx = [ADXChartDb chartsOf:s dx:YES];
            for (NSArray *set in @[std, dx]) {
                for (NSArray *c in set) {
                    double lv = [c[1] doubleValue];
                    NSString *b = LevelBucket(lv);
                    NSMutableArray *arr = groups[b];
                    if (!arr) { arr = [NSMutableArray array]; groups[b] = arr; }
                    [arr addObject:@{@"song": s, @"chart": c}];
                }
            }
        }
        NSMutableArray *titles = [NSMutableArray array];
        for (int i = 0; i <= 15; i++) {
            [titles addObject:[NSString stringWithFormat:@"Lv%d", i]];
            [titles addObject:[NSString stringWithFormat:@"Lv%d+", i]];
        }
        for (NSString *t in [titles reverseObjectEnumerator]) {
            NSArray *rows = groups[t];
            if (!rows.count) continue;
            [out addObject:@{@"title": [NSString stringWithFormat:@"%@（%lu）", t, (unsigned long)rows.count],
                             @"rows": rows}];
        }
        self.sections = [self applyOpen:out];
        return;
    }

    if (self.mode == 3) {
        // 版本（日服版本名，按 28 档顺序）
        NSMutableDictionary *groups = [NSMutableDictionary dictionary];
        for (NSArray *s in songs) {
            BOOL dx = [ADXChartDb hasDx:s];
            NSString *v = [ADXChartDb jpVersionName:s dx:dx];
            if (v.length == 0) v = [ADXChartDb jpVersionName:s dx:!dx];
            if (v.length == 0) v = @"未知版本";
            NSMutableArray *arr = groups[v];
            if (!arr) { arr = [NSMutableArray array]; groups[v] = arr; }
            [arr addObject:@{@"song": s}];
        }
        NSArray *order = @[@"maimai", @"maimai PLUS", @"maimai GreeN", @"maimai GreeN PLUS",
                           @"maimai ORANGE", @"maimai ORANGE PLUS", @"maimai PiNK", @"maimai PiNK PLUS",
                           @"maimai MURASAKi", @"maimai MURASAKi PLUS", @"maimai MiLK", @"maimai MiLK PLUS",
                           @"maimai FiNALE", @"maimai DX", @"maimai DX PLUS", @"maimai DX Splash",
                           @"maimai DX Splash PLUS", @"maimai DX UNiVERSE", @"maimai DX UNiVERSE PLUS",
                           @"maimai DX FESTiVAL", @"maimai DX FESTiVAL PLUS", @"maimai DX BUDDiES",
                           @"maimai DX BUDDiES PLUS", @"maimai DX PRiSM", @"maimai DX PRiSM PLUS",
                           @"maimai DX CiRCLE", @"maimai DX CiRCLE PLUS", @"maimai DX MAGiCAL"];
        for (NSString *v in [order reverseObjectEnumerator]) {
            NSArray *rows = groups[v];
            if (!rows.count) continue;
            [out addObject:@{@"title": [NSString stringWithFormat:@"%@（%lu）", v, (unsigned long)rows.count],
                             @"rows": rows}];
        }
        self.sections = [self applyOpen:out];
        return;
    }

    // 达成率
    NSMutableDictionary *groups = [NSMutableDictionary dictionary];
    for (NSArray *s in songs) {
        NSArray *sets[2] = {[ADXChartDb chartsOf:s dx:NO], [ADXChartDb chartsOf:s dx:YES]};
        for (int k = 0; k < 2; k++) {
            for (NSArray *c in sets[k]) {
                double rate = BRRateOf(s, c);
                if (rate < 0) continue;
                NSString *tier = RankOf(rate);
                NSMutableArray *arr = groups[tier];
                if (!arr) { arr = [NSMutableArray array]; groups[tier] = arr; }
                [arr addObject:@{@"song": s, @"chart": c, @"rate": @(rate)}];
            }
        }
    }
    for (NSString *t in [[RankTiers() reverseObjectEnumerator] allObjects]) {
        NSArray *rows = groups[t];
        if (!rows.count) continue;
        [out addObject:@{@"title": [NSString stringWithFormat:@"%@ · %@（%lu）", t, RankRangeText(t), (unsigned long)rows.count],
                         @"rows": rows}];
    }
    self.sections = [self applyOpen:out];
}

/// 收起状态下只保留标题行
- (NSArray *)applyOpen:(NSArray *)groups
{
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *g in groups) {
        NSString *key = [NSString stringWithFormat:@"%ld|%@", (long)self.mode, g[@"title"]];
        BOOL open = [self.openKeys containsObject:key];
        [out addObject:@{@"title": g[@"title"], @"rows": (open ? g[@"rows"] : @[]), @"open": @(open)}];
    }
    return out;
}

#pragma mark - 表格

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section >= (NSInteger)self.sections.count) return 0;
    NSDictionary *g = self.sections[section];
    NSArray *rows = g[@"rows"];
    return g[@"title"] && [g[@"title"] length] ? 1 + rows.count : rows.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section >= (NSInteger)self.sections.count) return 58;
    NSDictionary *g = self.sections[indexPath.section];
    BOOL hasHead = g[@"title"] && [g[@"title"] length];
    if (hasHead && indexPath.row == 0) return 48;
    return 58;
}

- (BOOL)isHeadRow:(NSIndexPath *)indexPath
{
    if (indexPath.section >= (NSInteger)self.sections.count) return NO;
    NSDictionary *g = self.sections[indexPath.section];
    return (g[@"title"] && [g[@"title"] length] && indexPath.row == 0);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section >= (NSInteger)self.sections.count) return [[UITableViewCell alloc] init];
    NSDictionary *g = self.sections[indexPath.section];
    BOOL hasHead = g[@"title"] && [g[@"title"] length];

    if (hasHead && indexPath.row == 0) {
        ADXBrowseHead *c = [tableView dequeueReusableCellWithIdentifier:@"head"];
        if (!c) c = [[ADXBrowseHead alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"head"];
        c.title.text = g[@"title"];
        [c setOpen:[g[@"open"] boolValue]];

        for (UIGestureRecognizer *gr in [c.contentView.gestureRecognizers copy])
            [c.contentView removeGestureRecognizer:gr];
        c.contentView.tag = indexPath.section;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(headerTapped:)];
        [c.contentView addGestureRecognizer:tap];
        return c;
    }

    ADXBrowseRow *c = [tableView dequeueReusableCellWithIdentifier:@"row"];
    if (!c) c = [[ADXBrowseRow alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"row"];

    NSInteger idx = hasHead ? indexPath.row - 1 : indexPath.row;
    NSArray *rows = g[@"rows"];
    if (idx < 0 || idx >= (NSInteger)rows.count) return c;

    NSDictionary *item = rows[idx];
    NSArray *song = item[@"song"];
    NSArray *chart = item[@"chart"];

    c.name.text = song[1];
    c.songId = [song[0] intValue];

    NSMutableArray *bits = [NSMutableArray array];
    if (chart) {
        [bits addObject:[NSString stringWithFormat:@"%@ %@", DiffNameForBrowse([chart[0] integerValue]),
                         [ADXChartDb levelTextOfChart:chart]]];
    }
    NSNumber *rate = item[@"rate"];
    if (rate) [bits addObject:[NSString stringWithFormat:@"%.4f%%", rate.doubleValue]];
    [bits addObject:[ADXChartDb numberText:song]];
    c.sub.text = [bits componentsJoinedByString:@" · "];

    c.cover.image = nil;
    c.cover.tag = c.songId;
    NSString *url = [ADXChartDb coverURL:song];
    NSString *dir = [ADXImage coverDir];
    int sid = [song[0] intValue];
    NSInteger expect = c.songId;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *img = url.length ? [ADXImage coverImageFor:sid url:url dir:dir]
                                  : [ADXImage coverImageFor:sid dir:dir];
        if (!img) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (c.cover.tag == expect) c.cover.image = img;
        });
    });
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([self isHeadRow:indexPath]) return;

    NSDictionary *g = self.sections[indexPath.section];
    BOOL hasHead = g[@"title"] && [g[@"title"] length];
    NSInteger idx = hasHead ? indexPath.row - 1 : indexPath.row;
    NSArray *rows = g[@"rows"];
    if (idx < 0 || idx >= (NSInteger)rows.count) return;

    NSArray *song = rows[idx][@"song"];
    int sid = [song[0] intValue];
    if (self.onSelect) self.onSelect(sid);
}

@end
