// MajPanel.m — 自制谱（majdata.net）：界面与「谱面查询」保持一致
#import "MajPanel.h"
#import "MajData.h"
#import "Zip.h"

#pragma mark - 曲绘缓存（自制谱专用，落在 Caches 里）

static NSString *MajCoverDir(void)
{
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/majcovers"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

static NSCache *MajCoverMem(void)
{
    static NSCache *c = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        c = [[NSCache alloc] init];
        c.countLimit = 240;
    });
    return c;
}

static NSString *MajCoverPath(NSString *chartId)
{
    NSString *name = [chartId stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return [[MajCoverDir() stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"png"];
}

static void MajLoadCover(NSString *chartId, UIImageView *iv, void (^done)(UIImage *img))
{
    if (!chartId.length) return;

    UIImage *mem = [MajCoverMem() objectForKey:chartId];
    if (mem) { iv.image = mem; if (done) done(mem); return; }

    NSString *path = MajCoverPath(chartId);
    UIImage *disk = [UIImage imageWithContentsOfFile:path];
    if (disk) {
        [MajCoverMem() setObject:disk forKey:chartId];
        iv.image = disk;
        if (done) done(disk);
        return;
    }

    NSString *url = [ADXMajData imageURLOf:chartId];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [req setValue:@"https://majdata.net/" forHTTPHeaderField:@"Referer"];
    [req setTimeoutInterval:20];

    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            if (!data.length) return;
            UIImage *img = [UIImage imageWithData:data];
            if (!img) return;
            [data writeToFile:path atomically:YES];
            [MajCoverMem() setObject:img forKey:chartId];
            dispatch_async(dispatch_get_main_queue(), ^{
                iv.image = img;
                if (done) done(img);
            });
        }];
    [t resume];
}

#pragma mark - 行

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

    self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];

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
    CGFloat tx = 16 + 40 + 12;
    self.name.frame = CGRectMake(tx, 11, w - tx - 34, 20);
    self.sub.frame = CGRectMake(tx, 32, w - tx - 34, 16);
}

@end

#pragma mark - 难度配色

static UIColor *MajDiff(int idx)
{
    switch (idx) {
        case 2: return [UIColor colorWithRed:0.91 green:0.62 blue:0.17 alpha:1.0];
        case 3: return [UIColor colorWithRed:0.84 green:0.29 blue:0.35 alpha:1.0];
        case 4: return [UIColor colorWithRed:0.59 green:0.36 blue:0.84 alpha:1.0];
        case 5: return [UIColor colorWithRed:0.93 green:0.93 blue:0.96 alpha:1.0];
        case 6: return [UIColor colorWithRed:0.45 green:0.31 blue:0.55 alpha:1.0];
        default: return [UIColor colorWithRed:0.26 green:0.66 blue:0.36 alpha:1.0];
    }
}

static UIColor *MajInk(int idx)
{
    return (idx == 5) ? [UIColor colorWithWhite:0.2 alpha:1.0] : [UIColor whiteColor];
}

#pragma mark - 详情 + 下载

@interface ADXMajSheet : UIView
@property (nonatomic, strong) NSDictionary *item;
+ (void)presentItem:(NSDictionary *)item inView:(UIView *)host;
@end

@interface ADXMajSheet ()
@property (nonatomic, strong) UIView *dim;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIButton *favButton;
@property (nonatomic, strong) UIButton *downloadButton;
@property (nonatomic, strong) UIProgressView *bar;
@property (nonatomic, strong) UILabel *status;
@property (nonatomic, strong) UISwitch *bgaSwitch;
@property (nonatomic, strong) UIImageView *cover;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) BOOL imported;
@property (nonatomic, copy) NSString *folder;

- (void)build;
- (void)buildContentInWidth:(CGFloat)w;
- (UIButton *)pill:(NSString *)title frame:(CGRect)f;
- (NSString *)favKey;
- (void)refreshFav;
- (void)favTapped;
- (void)downloadTapped;
- (void)close;
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
    self.dim = [[UIView alloc] initWithFrame:self.bounds];
    self.dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.32];
    self.dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:self.dim];
    [self.dim addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(close)]];

    CGFloat w = MIN(560.0, self.bounds.size.width - 48);
    CGFloat h = MIN(620.0, self.bounds.size.height - 80);

    self.card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    self.card.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    self.card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.card.layer.cornerRadius = 16;
    self.card.clipsToBounds = YES;
    self.card.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                 UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self addSubview:self.card];

    self.scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h - 64)];
    self.scroll.alwaysBounceVertical = YES;
    [self.card addSubview:self.scroll];

    [self buildContentInWidth:w];

    CGFloat by = h - 56;
    CGFloat bw = (w - 32 - 12) / 2;

    self.favButton = [self pill:@"收藏夹" frame:CGRectMake(16, by, bw, 42)];
    [self.favButton addTarget:self action:@selector(favTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:self.favButton];

    self.downloadButton = [self pill:@"谱面下载" frame:CGRectMake(16 + bw + 12, by, bw, 42)];
    [self.downloadButton addTarget:self action:@selector(downloadTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:self.downloadButton];

    [self refreshFav];

    self.alpha = 0;
    self.card.transform = CGAffineTransformMakeScale(0.94, 0.94);
    [UIView performWithoutAnimation:^{ self.alpha = 1; }];
    [UIView animateWithDuration:0.18 animations:^{ self.card.transform = CGAffineTransformIdentity; }];
}

- (UIButton *)pill:(NSString *)title frame:(CGRect)f
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = f;
    b.backgroundColor = [UIColor secondarySystemBackgroundColor];
    b.layer.cornerRadius = 10;
    b.layer.borderWidth = 0.5;
    b.layer.borderColor = [UIColor separatorColor].CGColor;
    b.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    return b;
}

- (void)buildContentInWidth:(CGFloat)w
{
    NSDictionary *it = self.item;
    CGFloat x = 16;
    CGFloat y = 12;
    CGFloat cw = w - 32;

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(x, y, cw, 150)];
    card.backgroundColor = [UIColor secondarySystemBackgroundColor];
    card.layer.cornerRadius = 12;
    [self.scroll addSubview:card];

    self.cover = [[UIImageView alloc] initWithFrame:CGRectMake(8, 8, 84, 84)];
    self.cover.contentMode = UIViewContentModeScaleAspectFill;
    self.cover.clipsToBounds = YES;
    self.cover.layer.cornerRadius = 8;
    self.cover.backgroundColor = [UIColor tertiarySystemFillColor];
    [card addSubview:self.cover];
    MajLoadCover(it[@"id"], self.cover, nil);

    CGFloat tx = 8 + 84 + 12;
    CGFloat tw = cw - tx - 8;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(tx, 10, tw, 44)];
    title.font = [UIFont boldSystemFontOfSize:19];
    title.numberOfLines = 2;
    title.text = it[@"title"];
    [card addSubview:title];

    UILabel *artist = [[UILabel alloc] initWithFrame:CGRectMake(tx, 56, tw, 18)];
    artist.font = [UIFont systemFontOfSize:14];
    artist.textColor = [UIColor secondaryLabelColor];
    artist.text = it[@"artist"];
    [card addSubview:artist];

    CGFloat colW = (cw - 32) / 3.0;
    NSArray *caps = @[@"谱师", @"上传者", @"来源"];
    NSArray *vals = @[it[@"designer"] ?: @"-", it[@"uploader"] ?: @"-", @"majdata.net"];
    for (NSInteger i = 0; i < 3; i++) {
        UILabel *cap = [[UILabel alloc] initWithFrame:CGRectMake(16 + colW * i, 100, colW, 14)];
        cap.font = [UIFont systemFontOfSize:11.5];
        cap.textColor = [UIColor tertiaryLabelColor];
        cap.text = caps[i];
        [card addSubview:cap];

        UILabel *val = [[UILabel alloc] initWithFrame:CGRectMake(16 + colW * i, 116, colW - 6, 18)];
        val.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        val.lineBreakMode = NSLineBreakByTruncatingTail;
        val.text = vals[i];
        [card addSubview:val];
    }

    y = CGRectGetMaxY(card.frame) + 12;

    NSArray *levels = [ADXMajData levelTextsOf:it];
    if (levels.count == 0) {
        UILabel *none = [[UILabel alloc] initWithFrame:CGRectMake(x, y, cw, 20)];
        none.font = [UIFont systemFontOfSize:13];
        none.textColor = [UIColor secondaryLabelColor];
        none.text = @"这张谱面没有填写难度";
        [self.scroll addSubview:none];
        y += 26;
    }
    for (NSDictionary *lv in levels) {
        NSInteger slot = [lv[@"slot"] integerValue];
        UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(x, y, cw, 64)];
        bar.backgroundColor = MajDiff((int)slot);
        bar.layer.cornerRadius = 10;
        bar.clipsToBounds = YES;
        [self.scroll addSubview:bar];

        UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(14, 8, 88, 22)];
        name.font = [UIFont boldSystemFontOfSize:13];
        name.textColor = [MajInk((int)slot) colorWithAlphaComponent:0.9];
        name.text = lv[@"name"];
        [bar addSubview:name];

        UILabel *val = [[UILabel alloc] initWithFrame:CGRectMake(104, 4, cw - 120, 26)];
        val.font = [UIFont boldSystemFontOfSize:20];
        val.textColor = MajInk((int)slot);
        val.text = lv[@"value"];
        [bar addSubview:val];

        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(14, 31.5, cw - 28, 0.5)];
        line.backgroundColor = [MajInk((int)slot) colorWithAlphaComponent:0.22];
        [bar addSubview:line];

        UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(14, 36, cw - 28, 18)];
        sub.font = [UIFont systemFontOfSize:12];
        sub.textColor = [MajInk((int)slot) colorWithAlphaComponent:0.85];
        sub.text = [NSString stringWithFormat:@"谱师 %@", it[@"designer"] ?: @"-"];
        [bar addSubview:sub];

        y += 64 + 8;
    }

    y += 4;
    UILabel *bga = [[UILabel alloc] initWithFrame:CGRectMake(x, y, cw - 60, 20)];
    bga.font = [UIFont systemFontOfSize:13];
    bga.text = @"包含 BGA 视频";
    [self.scroll addSubview:bga];

    self.bgaSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(w - 16 - 51, y - 6, 51, 31)];
    [self.scroll addSubview:self.bgaSwitch];

    y += 32;
    self.bar = [[UIProgressView alloc] initWithFrame:CGRectMake(x, y, cw, 4)];
    self.bar.hidden = YES;
    [self.scroll addSubview:self.bar];

    y += 6;
    self.status = [[UILabel alloc] initWithFrame:CGRectMake(x, y, cw, 18)];
    self.status.font = [UIFont systemFontOfSize:12];
    self.status.textColor = [UIColor secondaryLabelColor];
    self.status.text = @"";
    [self.scroll addSubview:self.status];

    y += 22;
    self.scroll.contentSize = CGSizeMake(w, y);
}

#pragma mark 交互

- (NSString *)favKey
{
    return [NSString stringWithFormat:@"majfav.%@", self.item[@"id"]];
}

- (void)refreshFav
{
    BOOL on = [[NSUserDefaults standardUserDefaults] boolForKey:[self favKey]];
    [self.favButton setTitle:(on ? @"已收藏" : @"收藏夹") forState:UIControlStateNormal];
}

- (void)favTapped
{
    BOOL on = ![[NSUserDefaults standardUserDefaults] boolForKey:[self favKey]];
    [[NSUserDefaults standardUserDefaults] setBool:on forKey:[self favKey]];
    [self refreshFav];
}

- (void)downloadTapped
{
    if (self.running) {
        self.running = NO;
        [self.bar setProgress:0 animated:NO];
        self.status.text = @"已取消";
        [self.downloadButton setTitle:@"谱面下载" forState:UIControlStateNormal];
        return;
    }
    if (self.imported) return;

    self.running = YES;
    self.bar.hidden = NO;
    [self.downloadButton setTitle:@"取消" forState:UIControlStateNormal];

    __weak typeof(self) weakSelf = self;
    [ADXMajData download:self.item includeBGA:self.bgaSwitch.on progress:^(CGFloat ratio, NSString *status) {
        [weakSelf.bar setProgress:ratio animated:YES];
        weakSelf.status.text = status;
    } completion:^(NSString *folder, NSError *error) {
        weakSelf.running = NO;
        [weakSelf.bar setProgress:1 animated:YES];
        if (folder) {
            weakSelf.folder = folder;
            weakSelf.imported = YES;
            weakSelf.status.text = [NSString stringWithFormat:@"已导入 levels/%@", folder];
            [weakSelf.downloadButton setTitle:@"已导入" forState:UIControlStateNormal];
        } else {
            weakSelf.status.text = error.localizedDescription ?: @"下载失败";
            [weakSelf.downloadButton setTitle:@"重试" forState:UIControlStateNormal];
        }
    }];
}

- (void)close
{
    [UIView animateWithDuration:0.15 animations:^{ self.alpha = 0; } completion:^(BOOL f) {
        [self removeFromSuperview];
    }];
}

@end

#pragma mark - 面板

@interface ADXMajPanel () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic, strong) UILabel *hint;
@property (nonatomic, strong) UIScrollView *chipScroll;
@property (nonatomic, strong) NSMutableArray *chips;
@property (nonatomic, strong) UIButton *expandButton;
@property (nonatomic, strong) UIButton *favButton;
@property (nonatomic, strong) UITableView *table;

@property (nonatomic, assign) NSInteger mode;
@property (nonatomic, strong) NSArray *groups;
@property (nonatomic, strong) NSMutableSet *openKeys;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL defaultOpened;

- (void)build;
- (void)reload;
- (UIButton *)capsule:(NSString *)title;
- (void)refreshChips;
- (void)chipTapped:(UIButton *)b;
- (void)expandAllTapped;
- (void)rebuildFromGroups;
- (void)refreshExpandTitle;
- (void)buildDefaultGroupWith:(NSArray *)items;
- (void)headerTapped:(UITapGestureRecognizer *)g;
- (NSDictionary *)itemAt:(NSIndexPath *)ip;
- (void)favTapped;
@end

@implementation ADXMajPanel

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = [UIColor clearColor];
    self.openKeys = [NSMutableSet set];
    [self build];
    [self reload];
    return self;
}

- (UIButton *)capsule:(NSString *)title
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    b.layer.cornerRadius = 15;
    b.layer.borderWidth = 0.5;
    b.layer.borderColor = [UIColor separatorColor].CGColor;
    b.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [b setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    [b setTitle:title forState:UIControlStateNormal];
    return b;
}

- (void)build
{
    self.search = [[UISearchBar alloc] initWithFrame:CGRectZero];
    self.search.placeholder = @"搜索谱面/作曲家/谱师…";
    self.search.searchBarStyle = UISearchBarStyleMinimal;
    [self.search setBackgroundImage:[[UIImage alloc] init]];
    self.search.delegate = self;
    [self addSubview:self.search];

    self.hint = [[UILabel alloc] initWithFrame:CGRectZero];
    self.hint.font = [UIFont systemFontOfSize:12];
    self.hint.textColor = [UIColor secondaryLabelColor];
    self.hint.text = @"来自 majdata.net 的第三方谱面，和官方谱面互不影响。";
    [self addSubview:self.hint];

    self.chipScroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.chipScroll.showsHorizontalScrollIndicator = NO;
    [self addSubview:self.chipScroll];

    self.chips = [NSMutableArray array];
    NSArray *names = @[@"默认", @"榜单"];
    for (NSInteger i = 0; i < (NSInteger)names.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.tag = i;
        b.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        b.layer.cornerRadius = 15;
        [b setTitle:names[i] forState:UIControlStateNormal];
        [b addTarget:self action:@selector(chipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.chipScroll addSubview:b];
        [self.chips addObject:b];
    }

    self.expandButton = [self capsule:@"全部折叠"];
    [self.expandButton addTarget:self action:@selector(expandAllTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.expandButton];

    self.favButton = [self capsule:@"收藏夹"];
    [self.favButton addTarget:self action:@selector(favTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.favButton];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
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

    self.search.frame = CGRectMake(16, 2, w - 32, 44);
    self.hint.frame = CGRectMake(16, 46, w - 32, 16);
    self.chipScroll.frame = CGRectMake(0, 68, w - 168, 38);

    CGFloat x = 16;
    for (UIButton *b in self.chips) {
        CGSize sz = [b.titleLabel.text sizeWithAttributes:@{NSFontAttributeName: b.titleLabel.font}];
        CGFloat bw = sz.width + 30;
        b.frame = CGRectMake(x, 4, bw, 30);
        x = CGRectGetMaxX(b.frame) + 8;
    }
    self.chipScroll.contentSize = CGSizeMake(x, 38);

    self.expandButton.frame = CGRectMake(w - 156, 72, 66, 30);
    self.favButton.frame = CGRectMake(w - 82, 72, 66, 30);
    self.table.frame = CGRectMake(0, 110, w, MAX(0, h - 110));
}

#pragma mark 数据

- (void)reload
{
    if (self.loading) return;
    self.loading = YES;

    __weak typeof(self) weakSelf = self;

    if (self.mode == 0) {
        NSString *q = self.search.text ?: @"";
        [ADXMajData listWithSearch:q sort:@"" completion:^(NSArray *items, NSError *error) {
            weakSelf.loading = NO;
            [weakSelf buildDefaultGroupWith:(items ?: @[])];
        }];
        return;
    }

    NSArray *sorts = @[@"hotp", @"playp", @"like", @"download"];
    NSArray *titles = @[@"游玩", @"评价", @"评论", @"下载"];
    NSMutableArray *bucket = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)sorts.count; i++) bucket[i] = @[];

    __block NSInteger left = (NSInteger)sorts.count;
    for (NSInteger i = 0; i < (NSInteger)sorts.count; i++) {
        [ADXMajData rankingWithSort:sorts[i] completion:^(NSArray *items, NSError *error) {
            bucket[i] = items ?: @[];
            left--;
            if (left > 0) return;

            weakSelf.loading = NO;
            NSMutableArray *out = [NSMutableArray array];
            for (NSInteger k = 0; k < (NSInteger)titles.count; k++) {
                NSArray *arr = bucket[k];
                NSString *t = [NSString stringWithFormat:@"%@（%lu）", titles[k], (unsigned long)arr.count];
                BOOL open = [weakSelf.openKeys containsObject:t];
                [out addObject:@{@"title": t, @"rows": (open ? arr : @[]), @"open": @(open), @"all": arr}];
            }
            weakSelf.groups = out;
            [weakSelf.table reloadData];
            [weakSelf refreshExpandTitle];
        }];
    }
}

- (void)buildDefaultGroupWith:(NSArray *)items
{
    NSString *t = [NSString stringWithFormat:@"全部自制谱（%lu）", (unsigned long)items.count];
    if (!self.defaultOpened) {
        [self.openKeys addObject:t];
        self.defaultOpened = YES;
    }

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
    self.defaultOpened = NO;
    [self refreshChips];
    [self reload];
}

- (void)refreshChips
{
    for (UIButton *b in self.chips) {
        BOOL on = (b.tag == self.mode);
        b.backgroundColor = on ? [UIColor systemBlueColor] : [UIColor secondarySystemGroupedBackgroundColor];
        b.layer.borderWidth = on ? 0.0 : 0.5;
        b.layer.borderColor = [UIColor separatorColor].CGColor;
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

- (void)favTapped
{
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"自制谱收藏"
                                                               message:@"自制谱的收藏列表还在做，先点曲目详情里的「收藏夹」单条收藏。"
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    UIViewController *host = self.window.rootViewController;
    while (host.presentedViewController) host = host.presentedViewController;
    [host presentViewController:ac animated:YES completion:nil];
}

#pragma mark 表格

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

    [v addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(headerTapped:)]];
    return v;
}

- (void)headerTapped:(UITapGestureRecognizer *)g
{
    NSInteger sec = g.view.tag;
    if (sec >= (NSInteger)self.groups.count) return;

    NSString *t = self.groups[sec][@"title"];
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

    MajLoadCover(it[@"id"], cell.cover, nil);
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

#pragma mark 搜索

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
