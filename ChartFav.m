// ChartFav.m — 收藏夹存储 + 收藏夹弹窗（资源管理式多选：选择/完成、全选、删除、长按拖动）
#import "ChartFav.h"
#import "ChartDb.h"
#import "B50Image.h"
#import "B50Core.h"
#import <math.h>

static NSString *const kFavKey = @"adx.favs";

static NSString *FavCoverDir(void)
{
    return [ADXImage coverDir];
}

// 曲绘内存缓存：多选时反复刷新不再让封面闪一下
static NSCache *FavCoverCache(void)
{
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 200;
    });
    return cache;
}

#pragma mark - 存储

@implementation ADXChartFav

+ (NSArray *)ids
{
    NSArray *a = [[NSUserDefaults standardUserDefaults] arrayForKey:kFavKey];
    return [a isKindOfClass:[NSArray class]] ? a : @[];
}

+ (BOOL)contains:(int)songId
{
    for (NSNumber *n in [self ids]) {
        if ([n intValue] == songId) return YES;
    }
    return NO;
}

+ (BOOL)toggle:(int)songId
{
    NSMutableArray *a = [NSMutableArray arrayWithArray:[self ids]];
    BOOL on = NO;
    NSInteger hit = NSNotFound;
    for (NSUInteger i = 0; i < a.count; i++) {
        if ([a[i] intValue] == songId) { hit = i; break; }
    }
    if (hit != NSNotFound) {
        [a removeObjectAtIndex:hit];
    } else {
        [a insertObject:@(songId) atIndex:0];
        on = YES;
    }
    [[NSUserDefaults standardUserDefaults] setObject:a forKey:kFavKey];
    return on;
}

+ (void)remove:(NSArray *)songIds
{
    NSMutableArray *a = [NSMutableArray arrayWithArray:[self ids]];
    for (NSNumber *n in songIds) {
        for (NSInteger i = (NSInteger)a.count - 1; i >= 0; i--) {
            if ([a[i] intValue] == [n intValue]) [a removeObjectAtIndex:i];
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:a forKey:kFavKey];
}

@end

#pragma mark - 行

@interface ADXFavCell : UITableViewCell
@property (nonatomic, strong) UIImageView *cover;
@property (nonatomic, strong) UILabel *name;
@property (nonatomic, strong) UILabel *sub;
@property (nonatomic, strong) UIImageView *check;
@end

@implementation ADXFavCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;

        _cover = [[UIImageView alloc] initWithFrame:CGRectMake(16, 10, 38, 38)];
        _cover.contentMode = UIViewContentModeScaleAspectFill;
        _cover.clipsToBounds = YES;
        _cover.layer.cornerRadius = 5;
        _cover.backgroundColor = [UIColor secondarySystemBackgroundColor];
        [self.contentView addSubview:_cover];

        _name = [[UILabel alloc] initWithFrame:CGRectMake(64, 9, 340, 19)];
        _name.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightSemibold];
        _name.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_name];

        _sub = [[UILabel alloc] initWithFrame:CGRectMake(64, 28, 340, 17)];
        _sub.font = [UIFont systemFontOfSize:11.5];
        _sub.textColor = [UIColor secondaryLabelColor];
        _sub.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_sub];

        _check = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 22, 22)];
        _check.contentMode = UIViewContentModeScaleAspectFit;
        _check.hidden = YES;
        self.accessoryView = _check;
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    BOOL arrow = (self.accessoryView == nil &&
                  self.accessoryType == UITableViewCellAccessoryDisclosureIndicator);
    CGFloat right = self.accessoryView ? 40 : (arrow ? 34 : 16);
    self.name.frame = CGRectMake(64, 9, w - 64 - right, 19);
    self.sub.frame = CGRectMake(64, 28, w - 64 - right, 17);
}

- (void)setChecked:(BOOL)on selecting:(BOOL)selecting
{
    if (!selecting) {
        self.check.hidden = YES;
        self.accessoryView = nil;
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;   // 和 B50 列表一样的 ›
        [self setNeedsLayout];
        return;
    }
    self.check.hidden = NO;
    self.accessoryView = self.check;      // accessoryView 会接管，箭头自动消失
    self.accessoryType = UITableViewCellAccessoryNone;
    self.check.image = [UIImage systemImageNamed:(on ? @"checkmark.circle.fill" : @"circle")];
    self.check.tintColor = on ? [UIColor systemBlueColor] : [UIColor tertiaryLabelColor];
}

@end

#pragma mark - 弹窗

@interface ADXChartFavSheet () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UIView *dim;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UILabel *empty;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *selectButton;
@property (nonatomic, strong) UIButton *allButton;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *deleteButton;

@property (nonatomic, copy) NSArray *all;              // 收藏的全部曲目
@property (nonatomic, copy) NSArray *songs;            // 当前显示（搜索过滤后）
@property (nonatomic, strong) NSMutableSet *picked;    // 选中的 songId
@property (nonatomic, assign) BOOL selecting;
@property (nonatomic, assign) NSInteger dragStart;
@property (nonatomic, copy) void (^openBlock)(int songId);
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic, strong) UIScrollView *chipScroll;
@property (nonatomic, strong) NSMutableArray *chips;
@property (nonatomic, assign) NSInteger mode;          // 0 默认 1 类别 2 难度 3 版本 4 达成率
@property (nonatomic, strong) NSArray *groups;
@property (nonatomic, strong) NSMutableSet *openKeys;
- (void)refreshChips;
- (void)chipTapped:(UIButton *)b;
- (NSString *)groupKeyForSong:(NSArray *)s order:(NSInteger *)order;
- (void)rebuildGroups;
- (void)headerTapped:(UITapGestureRecognizer *)g;
- (NSArray *)songAt:(NSIndexPath *)ip;
- (double)bestRateOf:(NSArray *)song;
@property (nonatomic, strong) NSMutableSet *dragBase;  // 开始拖动时已有的选中项
@property (nonatomic, assign) CGPoint dragPoint;       // 手指在 table 内容坐标系里的位置
@property (nonatomic, assign) CGPoint dragOrigin;      // 按下时的位置（判断有没有真的拖动）
@property (nonatomic, assign) BOOL dragged;            // 手指移动超过阈值后才允许边缘滚动
@property (nonatomic, assign) CGFloat scrollSpeed;     // 边缘自动滚动速度（pt/帧）
@property (nonatomic, strong) CADisplayLink *link;
@end

@implementation ADXChartFavSheet

+ (void)presentInView:(UIView *)host open:(void (^)(int songId))open
{
    if (!host) return;

    ADXChartFavSheet *sheet = [[ADXChartFavSheet alloc] initWithFrame:host.bounds];
    sheet.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    sheet.backgroundColor = [UIColor clearColor];
    sheet.openBlock = open;
    sheet.picked = [NSMutableSet set];

    UIView *dim = [[UIView alloc] initWithFrame:sheet.bounds];
    dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.38];
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [sheet addSubview:dim];
    sheet.dim = dim;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:sheet action:@selector(close)];
    [dim addGestureRecognizer:tap];

    [sheet build];
    [host addSubview:sheet];

    sheet.alpha = 0;
    [UIView animateWithDuration:0.18 animations:^{ sheet.alpha = 1; }];
}

- (void)build
{
    CGFloat w = MIN(520, self.bounds.size.width - 64);
    CGFloat h = MIN(600, self.bounds.size.height - 120);

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake((self.bounds.size.width - w) / 2,
                                                           (self.bounds.size.height - h) / 2, w, h)];
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 16;
    card.layer.masksToBounds = YES;
    card.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self addSubview:card];
    self.card = card;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, w - 220, 50)];
    title.text = @"收藏夹";
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    [card addSubview:title];
    self.titleLabel = title;

    // 第一行：搜索框
    UISearchBar *sb = [[UISearchBar alloc] initWithFrame:CGRectMake(12, 50, w - 24, 44)];
    sb.searchBarStyle = UISearchBarStyleMinimal;
    sb.placeholder = @"搜索收藏的曲目";
    sb.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    sb.delegate = self;
    [card addSubview:sb];
    self.search = sb;

    // 第二行：分类胶囊
    UIScrollView *cs = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 92, w, 46)];
    cs.showsHorizontalScrollIndicator = NO;
    cs.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [card addSubview:cs];
    self.chipScroll = cs;
    self.chips = [NSMutableArray array];
    self.openKeys = [NSMutableSet set];

    NSArray *chipNames = @[@"默认", @"类别", @"难度", @"版本", @"达成率"];
    CGFloat cx = 12;
    for (NSInteger i = 0; i < (NSInteger)chipNames.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.tag = i;
        b.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        b.layer.cornerRadius = 15;
        b.layer.masksToBounds = YES;
        [b setTitle:chipNames[i] forState:UIControlStateNormal];
        [b addTarget:self action:@selector(chipTapped:) forControlEvents:UIControlEventTouchUpInside];
        CGFloat tw = [chipNames[i] sizeWithAttributes:@{NSFontAttributeName: b.titleLabel.font}].width + 24;
        b.frame = CGRectMake(cx, 6, tw, 30);
        cx += tw + 8;
        [cs addSubview:b];
        [self.chips addObject:b];
    }
    cs.contentSize = CGSizeMake(cx, 46);

    // 右上角：全选 / 选择（关闭按钮已去掉，点卡片外即可关闭）
    UIButton *all = [UIButton buttonWithType:UIButtonTypeSystem];
    all.frame = CGRectMake(w - 130, 0, 58, 50);
    [all setTitle:@"全选" forState:UIControlStateNormal];
    all.titleLabel.font = [UIFont systemFontOfSize:15];
    all.hidden = YES;
    [all addTarget:self action:@selector(toggleAll) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:all];
    self.allButton = all;

    UIButton *sel = [UIButton buttonWithType:UIButtonTypeSystem];
    sel.frame = CGRectMake(w - 70, 0, 58, 50);
    [sel setTitle:@"选择" forState:UIControlStateNormal];
    sel.titleLabel.font = [UIFont systemFontOfSize:15];
    [sel addTarget:self action:@selector(toggleSelecting) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:sel];
    self.selectButton = sel;

    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 49.5, w, 0.5)];
    line.backgroundColor = [UIColor separatorColor];
    [card addSubview:line];

    // 底部操作条（只在选择模式显示）
    CGFloat barH = 0;
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, h - barH, w, barH)];
    bar.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    bar.hidden = YES;
    [card addSubview:bar];
    self.bottomBar = bar;

    UIView *barLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 0.5)];
    barLine.backgroundColor = [UIColor separatorColor];
    [bar addSubview:barLine];

    UIColor *favRed = [UIColor colorWithRed:0xB4/255.0 green:0x53/255.0 blue:0x4B/255.0 alpha:1.0];

    UIButton *del = [UIButton buttonWithType:UIButtonTypeSystem];
    del.backgroundColor = [UIColor clearColor];
    del.layer.cornerRadius = 10;
    del.layer.borderWidth = 1.0;
    del.layer.borderColor = [favRed colorWithAlphaComponent:0.55].CGColor;
    [del setTitle:@"删除" forState:UIControlStateNormal];
    del.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [del setTitleColor:favRed forState:UIControlStateNormal];
    [del addTarget:self action:@selector(deleteTapped) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:del];
    self.deleteButton = del;

    // 只剩「删除」，拉通整条底栏（左右各留 16、上下各留 9）
    del.frame = CGRectMake(16, 9, w - 32, 42);

    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 138, w, h - 138)
                                                      style:UITableViewStylePlain];
    table.backgroundColor = [UIColor clearColor];
    table.separatorInset = UIEdgeInsetsMake(0, 64, 0, 0);
    table.rowHeight = 58;
    table.dataSource = self;
    table.delegate = self;
    [card addSubview:table];
    self.table = table;

    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    lp.minimumPressDuration = 0.28;
    [table addGestureRecognizer:lp];

    UILabel *empty = [[UILabel alloc] initWithFrame:CGRectMake(0, 180, w, 24)];
    empty.font = [UIFont systemFontOfSize:14];
    empty.textColor = [UIColor tertiaryLabelColor];
    empty.textAlignment = NSTextAlignmentCenter;
    [card addSubview:empty];
    self.empty = empty;

    [self reloadFavs];
    [self refreshHeader];
    [self refreshChips];
}

#pragma mark - 数据

- (void)reloadFavs
{
    NSMutableArray *list = [NSMutableArray array];
    for (NSNumber *n in [ADXChartFav ids]) {
        NSArray *s = [ADXChartDb songById:[n intValue]];
        if (s) [list addObject:s];
    }
    self.all = list;
    [self rebuildGroups];

    self.empty.hidden = (self.all.count > 0);
    self.empty.text = @"还没有收藏的曲目";
}

#pragma mark - 分组

- (void)refreshChips
{
    for (UIButton *b in self.chips) {
        BOOL on = (b.tag == self.mode);
        b.backgroundColor = on ? [UIColor systemBlueColor]
                               : [UIColor secondarySystemGroupedBackgroundColor];
        [b setTitleColor:(on ? [UIColor whiteColor] : [UIColor labelColor]) forState:UIControlStateNormal];
    }
}

- (void)chipTapped:(UIButton *)b
{
    self.mode = b.tag;
    [self refreshChips];
    [UIView performWithoutAnimation:^{
        [self rebuildGroups];
    }];
    // 分组默认全是收起的，此时没有任何行；直接跳第一行会越界崩溃，
    // 所以只把滚动位置拉回顶部。
    if (self.table.contentOffset.y > 0)
        [self.table setContentOffset:CGPointZero animated:NO];
}

static NSDictionary *FavRateMap(void)
{
    static NSDictionary *map;
    static BOOL loaded = NO;
    if (loaded) return map;
    loaded = YES;

    NSMutableDictionary *m = [NSMutableDictionary dictionary];
    NSString *path = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]
                      stringByAppendingPathComponent:@"cache"];
    NSDictionary *obj = [ADXB50 readCacheAt:path error:nil];
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *meta = obj[@"level_metadata"];
        if ([meta isKindOfClass:[NSDictionary class]]) {
            for (id key in meta) {
                NSDictionary *item = meta[key];
                NSArray *diff = item[@"difficulties"];
                if (![diff isKindOfClass:[NSArray class]]) continue;
                for (NSDictionary *d in diff) {
                    id st = d[@"stats"];
                    if (![st isKindOfClass:[NSDictionary class]]) continue;
                    NSNumber *rate = ((NSDictionary *)st)[@"achievementRate"];
                    if (![rate isKindOfClass:[NSNumber class]]) continue;
                    NSInteger idx = [d[@"id"] integerValue] - 2;
                    NSString *k = [NSString stringWithFormat:@"%@|%ld", item[@"title"], (long)idx];
                    m[k] = rate;
                }
            }
        }
    }
    map = m;
    return map;
}

static NSString *FavRank(double rate)
{
    if (rate < 0) return nil;
    if (rate >= 100.5) return @"SSS+";
    if (rate >= 100.0) return @"SSS";
    if (rate >= 99.5)  return @"SS+";
    if (rate >= 99.0)  return @"SS";
    if (rate >= 98.0)  return @"S+";
    if (rate >= 97.0)  return @"S";
    if (rate >= 94.0)  return @"AAA";
    if (rate >= 90.0)  return @"AA";
    if (rate >= 80.0)  return @"A";
    if (rate >= 75.0)  return @"BBB";
    if (rate >= 70.0)  return @"BB";
    if (rate >= 60.0)  return @"B";
    if (rate >= 50.0)  return @"C";
    return @"D";
}

static NSInteger FavRankOrder(NSString *r)
{
    NSArray *all = @[@"SSS+", @"SSS", @"SS+", @"SS", @"S+", @"S", @"AAA", @"AA",
                     @"A", @"BBB", @"BB", @"B", @"C", @"D"];
    NSInteger i = [all indexOfObject:r];
    return (i == NSNotFound) ? 99 : i;
}

/// 这首曲子里最好的那一档（用于分档）
- (double)bestRateOf:(NSArray *)song
{
    NSDictionary *map = FavRateMap();
    if (map.count == 0) return -1;
    double best = -1;
    NSString *title = song[1];
    for (NSInteger idx = 0; idx < 5; idx++) {
        NSNumber *n = map[[NSString stringWithFormat:@"%@|%ld", title, (long)idx]];
        if (n) best = MAX(best, [n doubleValue]);
    }
    return best;
}

/// 难度分档：floor 后，小数 ≥ 0.65 记作「+」
static NSString *FavLevelBucket(double v)
{
    NSInteger base = (NSInteger)floor(v);
    BOOL plus = (v - base) >= 0.65;
    return [NSString stringWithFormat:@"Lv%ld%@", (long)base, plus ? @"+" : @""];
}

- (NSString *)groupKeyForSong:(NSArray *)s order:(NSInteger *)order
{
    if (self.mode == 1) {
        NSString *g = [ADXChartDb jpGenreName:s];
        if (!g.length) g = [ADXChartDb genreName:s];
        g = [g stringByReplacingOccurrencesOfString:@"＆" withString:@" "];
        g = [g stringByReplacingOccurrencesOfString:@"&" withString:@" "];
        if (!g.length) g = @"其他";
        *order = 0;
        return g;
    }
    if (self.mode == 2) {
        double top = 0;
        BOOL any = NO;
        for (NSNumber *dx in @[@YES, @NO]) {
            for (NSArray *c in [ADXChartDb chartsOf:s dx:[dx boolValue]]) {
                double v = [c[1] doubleValue];
                if (v > top) { top = v; any = YES; }
            }
        }
        if (!any) return @"其他";
        *order = -(NSInteger)(top * 100);
        return FavLevelBucket(top);
    }
    if (self.mode == 3) {
        BOOL dx = [ADXChartDb hasDx:s];
        NSString *v = [ADXChartDb jpVersionName:s dx:dx];
        if (!v.length) v = [ADXChartDb versionName:s];
        if (!v.length) v = @"其他";
        *order = 0;
        return v;
    }
    if (self.mode == 4) {
        double r = [self bestRateOf:s];
        NSString *rank = FavRank(r);
        if (!rank) return nil;               // 没打过的不参与达标率分档
        *order = FavRankOrder(rank);
        return rank;
    }
    *order = 0;
    return nil;
}

- (void)rebuildGroups
{
    NSString *q = [self.search.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSArray *src = self.all;

    if (q.length) {
        NSString *lower = [q lowercaseString];
        NSMutableArray *f = [NSMutableArray array];
        for (NSArray *s in self.all) {
            NSString *t = [(NSString *)s[1] lowercaseString];
            NSString *a = [(NSString *)s[2] lowercaseString];
            if ([t containsString:lower] || [a containsString:lower]) [f addObject:s];
        }
        src = f;
    }
    self.songs = src;

    NSMutableArray *groups = [NSMutableArray array];
    if (self.mode > 0) {
        NSMutableDictionary *map = [NSMutableDictionary dictionary];
        NSMutableDictionary *orders = [NSMutableDictionary dictionary];
        for (NSArray *s in src) {
            NSInteger ord = 0;
            NSString *key = [self groupKeyForSong:s order:&ord];
            if (!key.length) continue;
            NSMutableArray *arr = map[key];
            if (!arr) {
                arr = [NSMutableArray array];
                map[key] = arr;
                orders[key] = @(ord);
            }
            [arr addObject:s];
        }

        NSArray *keys = [map.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
            NSInteger oa = [orders[a] integerValue];
            NSInteger ob = [orders[b] integerValue];
            if (oa != ob) return oa < ob ? NSOrderedAscending : NSOrderedDescending;
            return [a localizedStandardCompare:b];
        }];

        for (NSString *k in keys) {
            BOOL open = [self.openKeys containsObject:k];
            [groups addObject:@{@"title": k, @"rows": map[k], @"open": @(open)}];
        }
    }
    self.groups = groups;

    [self.table.layer removeAllAnimations];
    self.empty.hidden = (self.songs.count > 0);
    self.empty.text = self.all.count ? @"没有匹配的曲目" : @"还没有收藏的曲目";
    [self.table reloadData];
}

- (void)headerTapped:(UITapGestureRecognizer *)g
{
    NSInteger section = g.view.tag;
    if (section < 0 || section >= (NSInteger)self.groups.count) return;

    NSMutableDictionary *d = [self.groups[section] mutableCopy];
    BOOL open = ![d[@"open"] boolValue];
    NSString *key = d[@"title"];
    if (open) [self.openKeys addObject:key]; else [self.openKeys removeObject:key];
    d[@"open"] = @(open);

    NSMutableArray *arr = [self.groups mutableCopy];
    arr[section] = d;
    self.groups = arr;

    [UIView performWithoutAnimation:^{
        [self.table reloadSections:[NSIndexSet indexSetWithIndex:section]
                  withRowAnimation:UITableViewRowAnimationNone];
    }];
}

- (NSArray *)songAt:(NSIndexPath *)ip
{
    if (self.selecting || self.mode == 0) {
        if (ip.row >= (NSInteger)self.songs.count) return nil;
        return self.songs[ip.row];
    }
    if (ip.section >= (NSInteger)self.groups.count) return nil;
    NSArray *rows = self.groups[ip.section][@"rows"];
    if (ip.row >= (NSInteger)rows.count) return nil;
    return rows[ip.row];
}

- (void)refreshHeader
{
    [self.selectButton setTitle:(self.selecting ? @"完成" : @"选择") forState:UIControlStateNormal];
    self.allButton.hidden = !self.selecting;
    self.titleLabel.text = self.selecting
        ? [NSString stringWithFormat:@"已选 %lu 项", (unsigned long)self.picked.count]
        : @"收藏夹";
}

- (void)setSelectingMode:(BOOL)on
{
    self.selecting = on;
    if (!on) {
        [self.picked removeAllObjects];
        [self stopAutoScroll];
    }

    CGFloat w = self.card.bounds.size.width;
    CGFloat h = self.card.bounds.size.height;
    CGFloat barH = on ? 60 : 0;

    if (on) {
        self.mode = 0;
        [self refreshChips];
        [self rebuildGroups];
    }

    // 关掉隐式动画，避免「选择/完成」切换时整块渐隐渐显
    [UIView performWithoutAnimation:^{
        self.bottomBar.hidden = !on;
        self.bottomBar.frame = CGRectMake(0, h - barH, w, barH);
        self.search.hidden = on;
        self.chipScroll.hidden = on;
        CGFloat top = on ? 50 : 138;
        self.table.frame = CGRectMake(0, top, w, h - top - barH);
        [self.table reloadData];
        [self refreshHeader];
        [self.card layoutIfNeeded];
    }];
}

- (void)toggleSelecting
{
    [self setSelectingMode:!self.selecting];
}

- (void)toggleAll
{
    if (self.picked.count == self.songs.count) {
        [self.picked removeAllObjects];
    } else {
        for (NSArray *s in self.songs) [self.picked addObject:s[0]];
    }
    [self refreshChecks];
    [self refreshHeader];
}

/// 只刷新可见行的勾选状态，不整表 reload（避免曲绘闪烁）
- (void)refreshChecks
{
    for (UITableViewCell *c in self.table.visibleCells) {
        if (![c isKindOfClass:[ADXFavCell class]]) continue;
        NSIndexPath *ip = [self.table indexPathForCell:c];
        if (!ip || ip.row >= (NSInteger)self.songs.count) continue;
        NSArray *s = self.songs[ip.row];
        [(ADXFavCell *)c setChecked:[self.picked containsObject:s[0]] selecting:self.selecting];
    }
}

- (void)deleteTapped
{
    if (self.picked.count == 0) return;

    [ADXChartFav remove:self.picked.allObjects];
    [self.picked removeAllObjects];
    [self reloadFavs];
    [self refreshHeader];
}

#pragma mark - 长按拖动多选

- (void)handleLongPress:(UILongPressGestureRecognizer *)g
{
    CGPoint p = [g locationInView:self.table];

    if (g.state == UIGestureRecognizerStateBegan) {
        NSIndexPath *ip = [self.table indexPathForRowAtPoint:p];
        if (!ip) return;
        if (!self.selecting) [self setSelectingMode:YES];

        // 记住拖动前已有的选中项，拖动只做并集，不清空别人
        self.dragBase = [NSMutableSet setWithSet:self.picked];
        self.dragStart = ip.row;
        self.dragPoint = p;
        self.dragOrigin = p;
        self.dragged = NO;          // 只是长按、还没滑动 → 不许自动滚动
        [self updateSelectionAtPoint:p];
        return;
    }

    if (g.state == UIGestureRecognizerStateChanged) {
        if (!self.selecting) return;
        self.dragPoint = p;

        if (!self.dragged) {
            CGFloat dx = p.x - self.dragOrigin.x;
            CGFloat dy = p.y - self.dragOrigin.y;
            if (sqrt(dx * dx + dy * dy) > 8.0) self.dragged = YES;
        }

        [self updateSelectionAtPoint:p];
        if (self.dragged) [self updateAutoScroll];
        return;
    }

    [self stopAutoScroll];
}

- (void)updateSelectionAtPoint:(CGPoint)p
{
    NSIndexPath *ip = [self.table indexPathForRowAtPoint:p];
    if (!ip && self.songs.count) {
        // 手指滑出表格时，按方向补到首/末行，保证拖动不中断
        CGFloat h = self.table.contentSize.height;
        if (p.y < 0) ip = [NSIndexPath indexPathForRow:0 inSection:0];
        else if (p.y > h) ip = [NSIndexPath indexPathForRow:self.songs.count - 1 inSection:0];
    }
    if (!ip || ip.row >= (NSInteger)self.songs.count) return;

    NSInteger a = MIN(self.dragStart, ip.row);
    NSInteger b = MAX(self.dragStart, ip.row);

    NSMutableSet *set = [NSMutableSet setWithSet:self.dragBase ?: [NSSet set]];
    for (NSInteger i = a; i <= b; i++) {
        if (i >= 0 && i < (NSInteger)self.songs.count) [set addObject:self.songs[i][0]];
    }
    self.picked = set;

    [self refreshChecks];
    [self refreshHeader];
}

// 手指靠近上下边缘就开始自动滚动，越贴边越快（最多 14pt/帧）
- (void)updateAutoScroll
{
    if (!self.dragged) { [self stopAutoScroll]; return; }   // 没滑动就不滚
    CGFloat h = self.table.bounds.size.height;
    CGFloat y = self.dragPoint.y - self.table.contentOffset.y;   // 手指在可视区里的相对位置
    CGFloat edge = 56.0, speed = 0;

    if (y < edge) speed = -(edge - MAX(0.0, y)) / edge;
    else if (y > h - edge) speed = (MIN(edge, y - (h - edge))) / edge;
    speed *= 14.0;

    self.scrollSpeed = speed;
    if (fabs(speed) < 0.4) [self stopAutoScroll];
    else [self startAutoScroll];
}

- (void)startAutoScroll
{
    if (self.link) return;
    self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopAutoScroll
{
    [self.link invalidate];
    self.link = nil;
    self.scrollSpeed = 0;
}

- (void)tick:(CADisplayLink *)l
{
    CGFloat maxY = MAX(0.0, self.table.contentSize.height - self.table.bounds.size.height);
    CGFloat y = self.table.contentOffset.y + self.scrollSpeed;
    y = MAX(0.0, MIN(maxY, y));

    if (fabs(y - self.table.contentOffset.y) < 0.5) {   // 到底了就别再滚
        [self stopAutoScroll];
        return;
    }
    self.table.contentOffset = CGPointMake(0, y);
    [self updateSelectionAtPoint:self.dragPoint];
}

#pragma mark - 表格

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.selecting || self.mode == 0) return 1;
    return (NSInteger)self.groups.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.selecting || self.mode == 0) return (NSInteger)self.songs.count;
    if (section >= (NSInteger)self.groups.count) return 0;
    NSDictionary *g = self.groups[section];
    if (![g[@"open"] boolValue]) return 0;
    return (NSInteger)[g[@"rows"] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return (self.selecting || self.mode == 0) ? 0.0001 : 48;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (self.selecting || self.mode == 0) return nil;
    if (section >= (NSInteger)self.groups.count) return nil;

    NSDictionary *g = self.groups[section];
    CGFloat w = tableView.bounds.size.width;

    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 48)];
    v.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    v.tag = section;

    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(16, 14, 4, 20)];
    bar.backgroundColor = [UIColor systemBlueColor];
    bar.layer.cornerRadius = 2;
    [v addSubview:bar];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(28, 0, w - 28 - 44, 48)];
    t.text = g[@"title"];
    t.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [v addSubview:t];

    UIImageView *chev = [[UIImageView alloc] initWithFrame:CGRectMake(w - 38, 13, 22, 22)];
    chev.contentMode = UIViewContentModeCenter;
    chev.image = [UIImage systemImageNamed:([g[@"open"] boolValue] ? @"chevron.down" : @"chevron.right")];
    chev.tintColor = [UIColor tertiaryLabelColor];
    [v addSubview:chev];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(headerTapped:)];
    [v addGestureRecognizer:tap];
    return v;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ADXFavCell *cell = [tableView dequeueReusableCellWithIdentifier:@"fav"];
    if (!cell) cell = [[ADXFavCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"fav"];

    NSArray *s = [self songAt:indexPath];
    if (!s) return cell;
    cell.name.text = s[1];
    cell.sub.text = [NSString stringWithFormat:@"%@ · %@", s[2], [ADXChartDb numberText:s]];
    [cell setChecked:[self.picked containsObject:s[0]] selecting:self.selecting];

    int sid = [s[0] intValue];
    NSString *url = [ADXChartDb coverURL:s];
    cell.cover.tag = sid;

    UIImage *cached = [FavCoverCache() objectForKey:@(sid)];
    cell.cover.image = cached;          // 有缓存就直接用，选中切换时不会闪
    if (cached) return cell;

    __weak ADXFavCell *weakCell = cell;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *img = url.length ? [ADXImage coverImageFor:sid url:url dir:FavCoverDir()]
                                  : [ADXImage coverImageFor:sid dir:FavCoverDir()];
        if (!img) return;
        [FavCoverCache() setObject:img forKey:@(sid)];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakCell.cover.tag == sid) weakCell.cover.image = img;
        });
    });

    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style
        forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (style != UITableViewCellEditingStyleDelete || self.selecting) return;

    NSArray *s = [self songAt:indexPath];
    if (!s) return;
    [ADXChartFav toggle:[s[0] intValue]];
    [self reloadFavs];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSArray *s = [self songAt:indexPath];
    if (!s) return;
    if (self.selecting) {
        id key = s[0];
        if ([self.picked containsObject:key]) [self.picked removeObject:key];
        else [self.picked addObject:key];
        [self refreshChecks];
        [self refreshHeader];
        return;
    }

    int sid = [s[0] intValue];
    void (^open)(int) = self.openBlock;
    [self close];
    if (open) open(sid);
}

#pragma mark - 关闭

- (void)close
{
    [self stopAutoScroll];
    __weak __typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.15 animations:^{ weakSelf.alpha = 0; } completion:^(BOOL done) {
        [weakSelf removeFromSuperview];
    }];
}

@end
