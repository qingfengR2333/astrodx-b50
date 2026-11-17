// MajPanel.m — 自制谱（majdata.net）浏览 / 榜单 / 详情 / 下载
#import "MajPanel.h"
#import "MajData.h"
#import "Zip.h"

#pragma mark - 行 / 分组头

@interface ADXMajCell : UITableViewCell
@property (nonatomic, strong) UIImageView *cover;
@property (nonatomic, strong) UILabel *name;
@property (nonatomic, strong) UILabel *sub;
@end

@implementation ADXMajCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid
{
    self = [super initWithStyle:style reuseIdentifier:rid];
    if (!self) return nil;

    self.selectionStyle = UITableViewCellSelectionStyleDefault;

    _cover = [[UIImageView alloc] init];
    _cover.contentMode = UIViewContentModeScaleAspectFill;
    _cover.clipsToBounds = YES;
    _cover.layer.cornerRadius = 6;
    _cover.backgroundColor = [UIColor tertiarySystemFillColor];
    [self.contentView addSubview:_cover];

    _name = [[UILabel alloc] init];
    _name.font = [UIFont boldSystemFontOfSize:15];
    _name.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:_name];

    _sub = [[UILabel alloc] init];
    _sub.font = [UIFont systemFontOfSize:12.5];
    _sub.textColor = [UIColor secondaryLabelColor];
    _sub.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:_sub];

    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat h = self.contentView.bounds.size.height;
    CGFloat w = self.contentView.bounds.size.width;
    self.cover.frame = CGRectMake(16, (h - 40) / 2.0, 40, 40);
    CGFloat tx = CGRectGetMaxX(self.cover.frame) + 12;
    self.name.frame = CGRectMake(tx, 11, w - tx - 40, 20);
    self.sub.frame = CGRectMake(tx, 32, w - tx - 40, 16);
}

@end

@interface ADXMajHead : UIView
@end

@implementation ADXMajHead
@end

#pragma mark - 详情 / 下载浮层

@interface ADXMajSheet : UIView
@property (nonatomic, strong) NSDictionary *item;
@property (nonatomic, copy) void (^onClose)(void);
+ (void)presentItem:(NSDictionary *)item inView:(UIView *)host;
@end

@interface ADXMajSheet ()
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIView *dim;
@property (nonatomic, strong) UIProgressView *bar;
@property (nonatomic, strong) UILabel *status;
@property (nonatomic, strong) UIButton *mainButton;
@property (nonatomic, strong) UISwitch *bgaSwitch;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) BOOL done;
@property (nonatomic, copy) NSString *folder;
@end

@implementation ADXMajSheet

+ (void)presentItem:(NSDictionary *)item inView:(UIView *)host
{
    if (!host) return;
    ADXMajSheet *s = [[ADXMajSheet alloc] initWithFrame:host.bounds];
    s.item = item;
    s.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host addSubview:s];
    [s build];
}

- (void)build
{
    self.backgroundColor = [UIColor clearColor];

    self.dim = [[UIView alloc] initWithFrame:self.bounds];
    self.dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.38];
    self.dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:self.dim];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(close)];
    [self.dim addGestureRecognizer:tap];

    CGFloat w = MIN(520.0, self.bounds.size.width - 48);
    CGFloat h = MIN(560.0, self.bounds.size.height - 80);

    self.card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    self.card.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    self.card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.card.layer.cornerRadius = 16;
    self.card.clipsToBounds = YES;
    self.card.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                 UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self addSubview:self.card];

    self.scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h - 120)];
    self.scroll.alwaysBounceVertical = YES;
    [self.card addSubview:self.scroll];

    [self buildContent];

    self.bar = [[UIProgressView alloc] initWithFrame:CGRectMake(20, h - 118, w - 40, 4)];
    self.bar.hidden = YES;
    [self.card addSubview:self.bar];

    self.status = [[UILabel alloc] initWithFrame:CGRectMake(20, h - 110, w - 40, 18)];
    self.status.font = [UIFont systemFontOfSize:12];
    self.status.textColor = [UIColor secondaryLabelColor];
    self.status.text = @"";
    [self.card addSubview:self.status];

    self.mainButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.mainButton.frame = CGRectMake(20, h - 82, w - 40, 44);
    self.mainButton.backgroundColor = [UIColor systemBlueColor];
    self.mainButton.layer.cornerRadius = 10;
    self.mainButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [self.mainButton setTitle:@"下载到游戏" forState:UIControlStateNormal];
    [self.mainButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.mainButton addTarget:self action:@selector(mainTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:self.mainButton];

    UIButton *export = [UIButton buttonWithType:UIButtonTypeSystem];
    export.frame = CGRectMake(20, h - 32, w - 40, 26);
    export.titleLabel.font = [UIFont systemFontOfSize:13];
    [export setTitle:@"导出为 .zip" forState:UIControlStateNormal];
    [export setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    [export addTarget:self action:@selector(exportTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:export];

    self.alpha = 0;
    self.card.transform = CGAffineTransformMakeScale(0.94, 0.94);
    [UIView performWithoutAnimation:^{ self.alpha = 1; }];
    [UIView animateWithDuration:0.18 animations:^{
        self.card.transform = CGAffineTransformIdentity;
    }];
}

- (void)buildContent
{
    CGFloat w = self.card.bounds.size.width;
    NSDictionary *it = self.item;
    CGFloat y = 18;

    UIImageView *cover = [[UIImageView alloc] initWithFrame:CGRectMake(20, y, 88, 88)];
    cover.contentMode = UIViewContentModeScaleAspectFill;
    cover.clipsToBounds = YES;
    cover.layer.cornerRadius = 8;
    cover.backgroundColor = [UIColor tertiarySystemFillColor];
    [self.scroll addSubview:cover];

    NSString *img = [ADXMajData imageURLOf:it[@"id"]];
    [self loadImage:img into:cover];

    CGFloat tx = 20 + 88 + 14;
    CGFloat tw = w - tx - 20;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(tx, y, tw, 44)];
    title.font = [UIFont boldSystemFontOfSize:19];
    title.numberOfLines = 2;
    title.text = it[@"title"];
    [self.scroll addSubview:title];

    UILabel *artist = [[UILabel alloc] initWithFrame:CGRectMake(tx, y + 48, tw, 20)];
    artist.font = [UIFont systemFontOfSize:14];
    artist.textColor = [UIColor secondaryLabelColor];
    artist.text = it[@"artist"];
    [self.scroll addSubview:artist];

    UILabel *designer = [[UILabel alloc] initWithFrame:CGRectMake(tx, y + 70, tw, 18)];
    designer.font = [UIFont systemFontOfSize:12.5];
    designer.textColor = [UIColor tertiaryLabelColor];
    designer.text = [NSString stringWithFormat:@"谱师 %@", it[@"designer"] ?: @"-"];
    [self.scroll addSubview:designer];

    y += 96;

    NSArray *levels = [ADXMajData levelTextsOf:it];
    if (levels.count == 0) {
        UILabel *none = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w - 40, 20)];
        none.font = [UIFont systemFontOfSize:13];
        none.textColor = [UIColor secondaryLabelColor];
        none.text = @"这张谱面没有填写难度";
        [self.scroll addSubview:none];
        y += 28;
    } else {
        CGFloat cx = 20, cy = y;
        for (NSDictionary *lv in levels) {
            NSString *txt = [NSString stringWithFormat:@"%@ %@", lv[@"name"], lv[@"value"]];
            UIFont *f = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            CGFloat cw = [txt sizeWithAttributes:@{NSFontAttributeName: f}].width + 20;
            if (cx + cw > w - 20) { cx = 20; cy += 34; }
            UIButton *chip = [UIButton buttonWithType:UIButtonTypeSystem];
            chip.frame = CGRectMake(cx, cy, cw, 26);
            chip.backgroundColor = [UIColor tertiarySystemFillColor];
            chip.layer.cornerRadius = 13;
            chip.titleLabel.font = f;
            [chip setTitle:txt forState:UIControlStateNormal];
            [chip setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
            [self.scroll addSubview:chip];
            cx += cw + 8;
        }
        y = cy + 38;
    }

    UILabel *up = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w - 40, 18)];
    up.font = [UIFont systemFontOfSize:12.5];
    up.textColor = [UIColor secondaryLabelColor];
    up.text = [NSString stringWithFormat:@"上传者 %@", it[@"uploader"] ?: @"-"];
    [self.scroll addSubview:up];
    y += 26;

    UILabel *bga = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w - 120, 20)];
    bga.font = [UIFont systemFontOfSize:13];
    bga.text = @"包含 BGA 视频";
    [self.scroll addSubview:bga];

    self.bgaSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(w - 20 - 51, y - 6, 51, 31)];
    self.bgaSwitch.on = NO;
    [self.scroll addSubview:self.bgaSwitch];

    y += 36;
    self.scroll.contentSize = CGSizeMake(w, y + 10);
}

- (void)loadImage:(NSString *)url into:(UIImageView *)iv
{
    if (!url.length) return;
    static NSCache *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; cache.countLimit = 200; });

    UIImage *hit = [cache objectForKey:url];
    if (hit) { iv.image = hit; return; }

    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:url]
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            if (!data) return;
            UIImage *img = [UIImage imageWithData:data];
            if (!img) return;
            [cache setObject:img forKey:url];
            dispatch_async(dispatch_get_main_queue(), ^{ iv.image = img; });
        }];
    [t resume];
}

#pragma mark - 下载 / 导出

- (void)mainTapped
{
    if (self.running) {                 // 取消
        self.running = NO;
        [self.bar setProgress:0 animated:NO];
        self.status.text = @"已取消";
        [self.mainButton setTitle:@"下载到游戏" forState:UIControlStateNormal];
        return;
    }
    if (self.folder) return;            // 已导入

    self.running = YES;
    self.bar.hidden = NO;
    [self.mainButton setTitle:@"取消" forState:UIControlStateNormal];

    __weak typeof(self) weakSelf = self;
    [ADXMajData download:self.item includeBGA:self.bgaSwitch.on progress:^(CGFloat ratio, NSString *status) {
        [weakSelf.bar setProgress:ratio animated:YES];
        weakSelf.status.text = status;
    } completion:^(NSString *folder, NSError *error) {
        weakSelf.running = NO;
        [weakSelf.bar setProgress:1 animated:YES];
        if (folder) {
            weakSelf.folder = folder;
            weakSelf.status.text = [NSString stringWithFormat:@"已导入 levels/%@", folder];
            [weakSelf.mainButton setTitle:@"已导入" forState:UIControlStateNormal];
            weakSelf.mainButton.enabled = NO;
        } else {
            weakSelf.status.text = error.localizedDescription ?: @"下载失败";
            [weakSelf.mainButton setTitle:@"重试" forState:UIControlStateNormal];
            [weakSelf.mainButton setTitle:@"重试" forState:UIControlStateNormal];
            weakSelf.mainButton.enabled = YES;
        }
    }];
}

- (void)exportTapped
{
    if (!self.folder.length) {
        self.status.text = @"先点「下载到游戏」，导入完成后再导出";
        return;
    }

    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/levels"];
    NSString *path = [dir stringByAppendingPathComponent:self.folder];

    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                     [NSString stringWithFormat:@"%@.zip", self.folder]];
    NSError *err = nil;
    if (![ADXZip zipDirectory:path to:tmp error:&err]) {
        self.status.text = err.localizedDescription ?: @"打包失败";
        return;
    }

    UIActivityViewController *ac = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:tmp]]
                                                                     applicationActivities:nil];
    UIViewController *host = self.window.rootViewController;
    while (host.presentedViewController) host = host.presentedViewController;
    if (ac.popoverPresentationController) {
        ac.popoverPresentationController.sourceView = self.mainButton;
    }
    [host presentViewController:ac animated:YES completion:nil];
}

- (void)close
{
    [UIView animateWithDuration:0.15 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end

#pragma mark - 主面板

@interface ADXMajPanel () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic, strong) UIScrollView *chipScroll;
@property (nonatomic, strong) NSMutableArray *chips;
@property (nonatomic, strong) UIButton *expandButton;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UILabel *hint;

@property (nonatomic, assign) NSInteger mode;         // 0 默认 1 榜单
@property (nonatomic, strong) NSArray *groups;        // @{title, rows, open}
@property (nonatomic, strong) NSMutableSet *openKeys;
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, assign) BOOL loading;
@end

@implementation ADXMajPanel

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = [UIColor clearColor];
    self.mode = 0;
    self.openKeys = [NSMutableSet set];
    [self build];
    [self reload];
    return self;
}

- (void)build
{
    CGFloat w = self.bounds.size.width;

    self.search = [[UISearchBar alloc] initWithFrame:CGRectMake(8, 0, w - 16, 40)];
    self.search.placeholder = @"搜索谱面/作曲家/谱师…";
    self.search.searchBarStyle = UISearchBarStyleMinimal;
    self.search.delegate = self;
    [self addSubview:self.search];

    self.hint = [[UILabel alloc] initWithFrame:CGRectMake(16, 42, w - 32, 18)];
    self.hint.font = [UIFont systemFontOfSize:12];
    self.hint.textColor = [UIColor secondaryLabelColor];
    self.hint.text = @"来自 majdata.net 的第三方谱面，和官方谱面互不影响。";
    [self addSubview:self.hint];

    self.chipScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 64, w, 38)];
    self.chipScroll.showsHorizontalScrollIndicator = NO;
    [self addSubview:self.chipScroll];

    self.chips = [NSMutableArray array];
    NSArray *names = @[@"默认", @"榜单"];
    CGFloat x = 16;
    for (NSInteger i = 0; i < (NSInteger)names.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.tag = i;
        [b setTitle:names[i] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        b.layer.cornerRadius = 15;
        b.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
        CGSize sz = [names[i] sizeWithAttributes:@{NSFontAttributeName: b.titleLabel.font}];
        b.frame = CGRectMake(x, 4, sz.width + 30, 30);
        [b addTarget:self action:@selector(chipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.chipScroll addSubview:b];
        [self.chips addObject:b];
        x = CGRectGetMaxX(b.frame) + 8;
    }
    self.chipScroll.contentSize = CGSizeMake(x + 8, 38);

    self.expandButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.expandButton.frame = CGRectMake(w - 150, 68, 66, 30);
    self.expandButton.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.expandButton.layer.cornerRadius = 15;
    self.expandButton.layer.borderWidth = 0.5;
    self.expandButton.layer.borderColor = [UIColor separatorColor].CGColor;
    self.expandButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [self.expandButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    [self.expandButton setTitle:@"全部展开" forState:UIControlStateNormal];
    [self.expandButton addTarget:self action:@selector(expandAllTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.expandButton];

    self.table = [[UITableView alloc] initWithFrame:CGRectMake(0, 106, w, self.bounds.size.height - 106)
                                              style:UITableViewStylePlain];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.rowHeight = 58;
    self.table.separatorInset = UIEdgeInsetsZero;
    self.table.backgroundColor = [UIColor clearColor];
    [self.table registerClass:[ADXMajCell class] forCellReuseIdentifier:@"maj"];
    [self addSubview:self.table];

    [self refreshChips];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;

    self.search.frame = CGRectMake(8, 0, w - 16, 40);
    self.hint.frame = CGRectMake(16, 42, w - 32, 18);
    self.chipScroll.frame = CGRectMake(0, 64, w - 160, 38);
    self.expandButton.frame = CGRectMake(w - 150, 68, 66, 30);
    self.table.frame = CGRectMake(0, 106, w, h - 106);
}

#pragma mark - 数据

- (void)reload
{
    if (self.loading) return;
    self.loading = YES;

    NSString *q = self.search.text ?: @"";
    __weak typeof(self) weakSelf = self;

    if (self.mode == 0) {
        [ADXMajData listWithSearch:q sort:@"" completion:^(NSArray *items, NSError *error) {
            weakSelf.loading = NO;
            weakSelf.items = items ?: @[];
            [weakSelf rebuildGroups];
        }];
    } else {
        NSArray *sorts = @[@"hotp", @"playp", @"like", @"download"];
        NSArray *titles = @[@"游玩", @"评价", @"评论", @"下载"];

        NSMutableArray *bucket = [NSMutableArray array];
        for (NSInteger i = 0; i < sorts.count; i++) bucket[i] = @[];

        __block NSInteger left = (NSInteger)sorts.count;
        for (NSInteger i = 0; i < (NSInteger)sorts.count; i++) {
            [ADXMajData rankingWithSort:sorts[i] completion:^(NSArray *items, NSError *error) {
                bucket[i] = items ?: @[];
                left--;
                if (left > 0) return;

                weakSelf.loading = NO;
                NSMutableArray *groups = [NSMutableArray array];
                for (NSInteger k = 0; k < (NSInteger)titles.count; k++) {
                    NSString *t = [NSString stringWithFormat:@"%@（%lu）", titles[k], (unsigned long)[bucket[k] count]];
                    BOOL open = [weakSelf.openKeys containsObject:t];
                    [groups addObject:@{@"title": t,
                                        @"rows": (open ? bucket[k] : @[]),
                                        @"open": @(open),
                                        @"all": bucket[k]}];
                }
                weakSelf.groups = groups;
                [weakSelf.table reloadData];
                [weakSelf refreshExpandTitle];
            }];
        }
        return;
    }
}

- (void)rebuildGroups
{
    NSArray *items = self.items ?: @[];
    NSString *t = [NSString stringWithFormat:@"全部自制谱（%lu）", (unsigned long)items.count];
    BOOL open = [self.openKeys containsObject:t];

    self.groups = @[@{@"title": t, @"rows": (open ? items : @[]), @"open": @(open), @"all": items}];
    [self.table reloadData];
    [self refreshExpandTitle];
}

- (void)chipTapped:(UIButton *)b
{
    if (self.mode == b.tag) return;
    self.mode = b.tag;
    [self.openKeys removeAllObjects];
    [self refreshChips];
    [self reload];
}

- (void)refreshChips
{
    for (UIButton *b in self.chips) {
        BOOL on = (b.tag == self.mode);
        b.backgroundColor = on ? [UIColor systemBlueColor] : [UIColor secondarySystemGroupedBackgroundColor];
        [b setTitleColor:(on ? [UIColor whiteColor] : [UIColor labelColor]) forState:UIControlStateNormal];
    }
}

- (void)expandAllTapped
{
    BOOL allOpen = (self.groups.count > 0);
    for (NSDictionary *g in self.groups) {
        if (![self.openKeys containsObject:g[@"title"]]) { allOpen = NO; break; }
    }

    for (NSDictionary *g in self.groups) {
        if (allOpen) [self.openKeys removeObject:g[@"title"]];
        else [self.openKeys addObject:g[@"title"]];
    }
    [self rebuildFromGroups];
    [self refreshExpandTitle];
}

- (void)rebuildFromGroups
{
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *g in self.groups) {
        NSArray *all = g[@"all"] ?: @[];
        BOOL open = [self.openKeys containsObject:g[@"title"]];
        [out addObject:@{@"title": g[@"title"], @"rows": (open ? all : @[]), @"open": @(open), @"all": all}];
    }
    self.groups = out;
    [self.table reloadData];
}

- (void)refreshExpandTitle
{
    BOOL allOpen = (self.groups.count > 0);
    for (NSDictionary *g in self.groups) {
        if (![self.openKeys containsObject:g[@"title"]]) { allOpen = NO; break; }
    }
    [self.expandButton setTitle:(allOpen ? @"全部折叠" : @"全部展开") forState:UIControlStateNormal];
}

#pragma mark - 表格

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (NSInteger)self.groups.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section >= (NSInteger)self.groups.count) return 0;
    NSDictionary *g = self.groups[section];
    if (![g[@"open"] boolValue]) return 0;
    return (NSInteger)[g[@"rows"] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 44;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section >= (NSInteger)self.groups.count) return nil;
    NSDictionary *g = self.groups[section];
    CGFloat w = tableView.bounds.size.width;

    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 44)];
    v.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    v.tag = section;

    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 43.5, w, 0.5)];
    line.backgroundColor = [UIColor separatorColor];
    [v addSubview:line];

    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(16, 12, 4, 20)];
    bar.backgroundColor = [UIColor systemBlueColor];
    bar.layer.cornerRadius = 2;
    [v addSubview:bar];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(28, 0, w - 72, 44)];
    t.font = [UIFont boldSystemFontOfSize:16];
    t.text = g[@"title"];
    [v addSubview:t];

    UIImageView *chev = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:
        ([g[@"open"] boolValue] ? @"chevron.down" : @"chevron.right")]];
    chev.frame = CGRectMake(w - 38, 11, 22, 22);
    chev.contentMode = UIViewContentModeCenter;
    chev.tintColor = [UIColor tertiaryLabelColor];
    [v addSubview:chev];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(headerTapped:)];
    [v addGestureRecognizer:tap];
    return v;
}

- (void)headerTapped:(UITapGestureRecognizer *)g
{
    NSInteger sec = g.view.tag;
    if (sec >= (NSInteger)self.groups.count) return;

    NSDictionary *old = self.groups[sec];
    NSString *t = old[@"title"];
    if ([self.openKeys containsObject:t]) [self.openKeys removeObject:t];
    else [self.openKeys addObject:t];

    [self rebuildFromGroups];
    [self refreshExpandTitle];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ADXMajCell *cell = [tableView dequeueReusableCellWithIdentifier:@"maj"];
    if (!cell) cell = [[ADXMajCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"maj"];

    NSDictionary *it = [self itemAt:indexPath];
    if (!it) return cell;

    cell.name.text = it[@"title"];
    cell.sub.text = [NSString stringWithFormat:@"%@ · %@", it[@"artist"] ?: @"", it[@"designer"] ?: @""];

    cell.cover.image = nil;
    NSString *url = [ADXMajData imageURLOf:it[@"id"]];
    cell.cover.tag = [it[@"id"] hash];
    if (!url.length) return cell;

    __weak ADXMajCell *weakCell = cell;
    NSUInteger expect = cell.cover.tag;
    [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:url]
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            if (!data) return;
            UIImage *img = [UIImage imageWithData:data];
            if (!img) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (weakCell.cover.tag == expect) weakCell.cover.image = img;
            });
        }];
    return cell;
}

- (NSDictionary *)itemAt:(NSIndexPath *)ip
{
    if (ip.section >= (NSInteger)self.groups.count) return nil;
    NSArray *rows = self.groups[ip.section][@"rows"];
    if (ip.row >= (NSInteger)rows.count) return nil;
    return rows[ip.row];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *it = [self itemAt:indexPath];
    if (!it) return;
    [ADXMajSheet presentItem:it inView:self.window];
}

#pragma mark - 搜索

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    [self reload];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if (searchText.length == 0) [self reload];
}

@end
