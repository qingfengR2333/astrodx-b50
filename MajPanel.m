// MajPanel.m — 自制谱（majdata.net）：界面与「谱面查询」保持一致
#import "MajPanel.h"
#import "MajData.h"
#import "Zip.h"

#pragma mark - 曲绘缓存（自制谱专用，落在 Caches 里）

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

static void MajLoadCover(NSString *chartId, UIImageView *iv, void (^done)(UIImage *img))
{
    if (!chartId.length) return;

    UIImage *mem = [MajCoverMem() objectForKey:chartId];
    if (mem) { iv.image = mem; if (done) done(mem); return; }

    NSString *path = [ADXMajData coverPathOf:chartId];
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

@interface ADXMajDownloadSheet : UIView
@property (nonatomic, strong) NSDictionary *item;
@property (nonatomic, strong) UIView *dim;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIProgressView *bar;
@property (nonatomic, strong) UILabel *status;
@property (nonatomic, strong) UIButton *main;
@property (nonatomic, strong) UISwitch *bga;
@property (nonatomic, copy) NSString *folder;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *exportButton;
@property (nonatomic, strong) UILabel *subLabel;
@property (nonatomic, strong) UILabel *pill;
@property (nonatomic, strong) UILabel *srcLabel;
@property (nonatomic, strong) UILabel *bgaLabel;
@property (nonatomic, strong) UILabel *bgaHint;
+ (void)presentItem:(NSDictionary *)item host:(UIView *)host;
- (void)layoutCard;
@end

@interface ADXMajSheet : UIView
@property (nonatomic, strong) NSDictionary *item;
+ (instancetype)sheetWithItem:(NSDictionary *)item;
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
@property (nonatomic, strong) UIButton *starButton;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, copy) void (^onFavorites)(void);
@property (nonatomic, copy) void (^onClose)(void);

- (void)build;
- (void)buildContentInWidth:(CGFloat)w;
- (UIButton *)pill:(NSString *)title frame:(CGRect)f;
- (void)refreshFav;
- (void)favTapped;
- (void)downloadTapped;
- (void)close;
@end

@implementation ADXMajSheet

+ (instancetype)sheetWithItem:(NSDictionary *)item
{
    ADXMajSheet *s = [[ADXMajSheet alloc] initWithFrame:CGRectZero];
    s.item = item;
    return s;
}

- (void)build
{
    self.backgroundColor = [UIColor systemGroupedBackgroundColor];

    self.backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *chev = [UIImage systemImageNamed:@"chevron.left"
                            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15
                                                                                        weight:UIFontWeightSemibold]];
    [self.backButton setImage:chev forState:UIControlStateNormal];
    [self.backButton setTitle:@" 返回" forState:UIControlStateNormal];
    self.backButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.backButton.frame = CGRectMake(10, 4, 92, 32);
    self.backButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.backButton addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.backButton];

    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;

    self.scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 40, w, h - 40 - 60)];
    self.scroll.alwaysBounceVertical = YES;
    [self addSubview:self.scroll];

    [self buildContentInWidth:w];

    CGFloat by = h - 52;
    CGFloat bw = (w - 32 - 12) / 2;

    self.favButton = [self pill:@"收藏夹" frame:CGRectMake(16, by, bw, 42)];
    [self.favButton addTarget:self action:@selector(favTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.favButton];

    self.downloadButton = [self pill:@"谱面下载" frame:CGRectMake(16 + bw + 12, by, bw, 42)];
    [self.downloadButton addTarget:self action:@selector(downloadTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.downloadButton];

    [self refreshFav];
}

- (UIButton *)pill:(NSString *)title frame:(CGRect)f
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = f;
    b.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    b.layer.cornerRadius = 10;
    b.layer.borderWidth = 0.5;
    b.layer.borderColor = [UIColor separatorColor].CGColor;
    b.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
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
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 12;
    card.layer.borderWidth = 0.5;
    card.layer.borderColor = [UIColor separatorColor].CGColor;
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

    self.starButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.starButton.frame = CGRectMake(cw - 40, 6, 32, 32);
    self.starButton.tintColor = [UIColor systemGray3Color];
    [self.starButton addTarget:self action:@selector(starTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.starButton];
    tw -= 36;

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

- (void)refreshFav
{
    BOOL on = [ADXMajData isFavorite:self.item[@"id"]];
    UIImage *img = [UIImage systemImageNamed:(on ? @"star.fill" : @"star")
                           withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18
                                                                                       weight:UIFontWeightRegular]];
    [self.starButton setImage:img forState:UIControlStateNormal];
    self.starButton.tintColor = on ? [UIColor systemYellowColor] : [UIColor systemGray3Color];
    [self.favButton setTitle:@"收藏夹" forState:UIControlStateNormal];
}

- (void)starTapped
{
    [ADXMajData toggleFavorite:self.item];
    [self refreshFav];

    BOOL on = [ADXMajData isFavorite:self.item[@"id"]];
    UIView *host = self.window ?: self;

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectZero];
    t.text = on ? @"已收藏" : @"已取消收藏";
    t.font = [UIFont systemFontOfSize:13];
    t.textColor = [UIColor whiteColor];
    t.backgroundColor = [UIColor colorWithWhite:0 alpha:0.82];
    t.textAlignment = NSTextAlignmentCenter;
    t.layer.cornerRadius = 15;
    t.layer.masksToBounds = YES;

    CGFloat maxW = host.bounds.size.width - 80;
    CGSize sz = [t sizeThatFits:CGSizeMake(maxW, 30)];
    CGFloat w = MIN(maxW, sz.width + 30);
    t.frame = CGRectMake(round((host.bounds.size.width - w) / 2),
                         CGRectGetMaxY(host.bounds) - 104, w, 30);
    t.alpha = 0;
    [host addSubview:t];

    __weak UILabel *weakT = t;
    [UIView animateWithDuration:0.15 animations:^{
        weakT.alpha = 1;
    } completion:^(BOOL ok) {
        [UIView animateWithDuration:0.25 delay:1.0 options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            weakT.alpha = 0;
        } completion:^(BOOL done) {
            [weakT removeFromSuperview];
        }];
    }];
}

- (void)favTapped
{
    if (self.onFavorites) self.onFavorites();
}

- (void)downloadTapped
{
    [ADXMajDownloadSheet presentItem:self.item host:self.window];
}

- (void)legacyDownloadTapped
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
    void (^cb)(void) = self.onClose;
    [UIView animateWithDuration:0.15 animations:^{ self.alpha = 0; } completion:^(BOOL f) {
        [self removeFromSuperview];
        if (cb) cb();
    }];
}

@end

#pragma mark - 面板

#pragma mark - 面板

@interface ADXMajFavSheet : UIView <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UIView *dim;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic, strong) UIButton *defaultChip;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, copy) void (^onOpen)(NSDictionary *item);
+ (void)presentInView:(UIView *)host open:(void (^)(NSDictionary *item))open;
@end

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

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.rowHeight = 58;
    self.table.sectionHeaderHeight = 44;
    self.table.estimatedRowHeight = 0;
    self.table.estimatedSectionHeaderHeight = 0;
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
            if (error) {
                weakSelf.groups = @[];
                [weakSelf.table reloadData];
                return;
            }
            [weakSelf buildDefaultGroupWith:(items ?: @[])];
        }];
        return;
    }

    NSArray *sorts = @[@"hotp", @"playp", @"like", @"download"];
    NSArray *titles = @[@"游玩", @"评价", @"评论", @"下载"];
    NSMutableArray *bucket = [NSMutableArray arrayWithObjects:@[], @[], @[], @[], nil];

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

- (void)showDetail:(NSDictionary *)it
{
    if (!it) return;

    self.table.hidden = YES;
    self.chipScroll.hidden = YES;
    self.expandButton.hidden = YES;
    self.favButton.hidden = YES;

    ADXMajSheet *sheet = [ADXMajSheet sheetWithItem:it];
    __weak typeof(self) weakSelf = self;
    sheet.onFavorites = ^{ [weakSelf favTapped]; };
    sheet.onClose = ^{
        weakSelf.table.hidden = NO;
        weakSelf.chipScroll.hidden = NO;
        weakSelf.expandButton.hidden = NO;
        weakSelf.favButton.hidden = NO;
    };
    sheet.frame = CGRectMake(0, 68, self.bounds.size.width, self.bounds.size.height - 68);
    sheet.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:sheet];
    [sheet build];
}

- (void)favTapped
{
    __weak typeof(self) weakSelf = self;
    [ADXMajFavSheet presentInView:self.window open:^(NSDictionary *item) {
        [weakSelf showDetail:item];
    }];
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
    v.backgroundColor = [UIColor systemGroupedBackgroundColor];
    v.tag = section;


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

- (NSDictionary *)itemAt:(NSIndexPath *)ip
{
    if (ip.section >= (NSInteger)self.groups.count) return nil;
    NSArray *rows = self.groups[ip.section][@"rows"];
    if (ip.row >= (NSInteger)rows.count) return nil;
    return rows[ip.row];
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *it = [self itemAt:indexPath];
    if (!it) return;
    ADXMajSheet *sheet = [ADXMajSheet sheetWithItem:it];
    __weak typeof(self) weakSelf = self;
    sheet.onFavorites = ^{ [weakSelf favTapped]; };
    sheet.frame = self.bounds;
    sheet.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:sheet];
    [sheet build];
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



@implementation ADXMajFavSheet

+ (void)presentInView:(UIView *)host open:(void (^)(NSDictionary *))open
{
    if (!host) return;
    ADXMajFavSheet *s = [[ADXMajFavSheet alloc] initWithFrame:host.bounds];
    s.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    s.onOpen = open;
    [host addSubview:s];
    [s build];
}

- (void)build
{
    self.items = [[ADXMajData favoriteItems] mutableCopy];

    self.dim = [[UIView alloc] initWithFrame:self.bounds];
    self.dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.32];
    self.dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:self.dim];
    [self.dim addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(close)]];

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

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, w - 80, 50)];
    title.font = [UIFont boldSystemFontOfSize:17];
    title.text = @"收藏夹";
    [self.card addSubview:title];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(w - 60, 0, 48, 50);
    close.titleLabel.font = [UIFont systemFontOfSize:15];
    [close setTitle:@"关闭" forState:UIControlStateNormal];
    [close addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:close];

    self.search = [[UISearchBar alloc] initWithFrame:CGRectMake(16, 52, w - 32, 40)];
    self.search.placeholder = @"搜索收藏的曲目";
    self.search.searchBarStyle = UISearchBarStyleMinimal;
    [self.search setBackgroundImage:[[UIImage alloc] init]];
    self.search.delegate = self;
    [self.card addSubview:self.search];

    self.defaultChip = [UIButton buttonWithType:UIButtonTypeSystem];
    self.defaultChip.frame = CGRectMake(16, 96, 66, 30);
    self.defaultChip.backgroundColor = [UIColor systemBlueColor];
    self.defaultChip.layer.cornerRadius = 15;
    self.defaultChip.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [self.defaultChip setTitle:@"默认" forState:UIControlStateNormal];
    [self.defaultChip setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.card addSubview:self.defaultChip];

    self.table = [[UITableView alloc] initWithFrame:CGRectMake(0, 134, w, h - 134) style:UITableViewStylePlain];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.rowHeight = 58;
    self.table.sectionHeaderHeight = 44;
    self.table.estimatedRowHeight = 0;
    self.table.estimatedSectionHeaderHeight = 0;
    self.table.sectionHeaderTopPadding = 0;
    self.table.sectionFooterHeight = 0.01;
    self.table.separatorInset = UIEdgeInsetsZero;
    self.table.backgroundColor = [UIColor clearColor];
    [self.card addSubview:self.table];
}

- (void)close
{
    [UIView animateWithDuration:0.15 animations:^{ self.alpha = 0; } completion:^(BOOL f) {
        [self removeFromSuperview];
    }];
}

#pragma mark 数据

- (NSArray *)shownItems
{
    NSString *q = [self.search.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!q.length) return self.items;

    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *it in self.items) {
        BOOL hit = [it[@"title"] rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound ||
                   [it[@"artist"] rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound;
        if (hit) [out addObject:it];
    }
    return out;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)[self shownItems].count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section { return 44; }

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    CGFloat w = tableView.bounds.size.width;
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 44)];
    v.backgroundColor = [UIColor systemGroupedBackgroundColor];


    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(16, 12, 4, 20)];
    bar.backgroundColor = [UIColor systemBlueColor];
    bar.layer.cornerRadius = 2;
    [v addSubview:bar];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(28, 0, w - 72, 44)];
    t.font = [UIFont boldSystemFontOfSize:16];
    t.text = [NSString stringWithFormat:@"全部收藏（%lu）", (unsigned long)[self shownItems].count];
    [v addSubview:t];

    UIImageView *chev = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
    chev.frame = CGRectMake(w - 38, 11, 22, 22);
    chev.contentMode = UIViewContentModeCenter;
    chev.tintColor = [UIColor tertiaryLabelColor];
    [v addSubview:chev];

    return v;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *rid = @"majfav";
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:rid];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:rid];

    NSDictionary *it = [self shownItems][indexPath.row];
    c.textLabel.text = it[@"title"];
    c.textLabel.font = [UIFont boldSystemFontOfSize:15];
    c.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", it[@"artist"] ?: @"", it[@"designer"] ?: @""];
    c.detailTextLabel.font = [UIFont systemFontOfSize:12.5];
    c.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    c.imageView.image = nil;
    c.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    c.separatorInset = UIEdgeInsetsZero;

    NSString *cid = it[@"id"];
    if (cid.length) {
        UIImage *cached = [UIImage imageWithContentsOfFile:[ADXMajData coverPathOf:cid]];
        if (cached) c.imageView.image = cached;
    }
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *it = [self shownItems][indexPath.row];
    if (self.onOpen) self.onOpen(it);
    [self close];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (style != UITableViewCellEditingStyleDelete) return;
    NSDictionary *it = [self shownItems][indexPath.row];
    [ADXMajData toggleFavorite:it];
    [self.items removeObject:it];
    [tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self.table reloadData];
}

@end

#pragma mark - 自制谱下载浮层（与官谱同款，去掉「下载选项」）


@implementation ADXMajDownloadSheet

+ (void)presentItem:(NSDictionary *)item host:(UIView *)host
{
    if (!host) return;
    ADXMajDownloadSheet *s = [[ADXMajDownloadSheet alloc] initWithFrame:host.bounds];
    s.item = item;
    s.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host addSubview:s];
    [s build];
    s.alpha = 0;
    [UIView animateWithDuration:0.18 animations:^{ s.alpha = 1; }];
}

- (void)build
{
    self.dim = [[UIView alloc] initWithFrame:self.bounds];
    self.dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.38];
    self.dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:self.dim];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(close)];
    [self.dim addGestureRecognizer:tap];

    CGFloat w = MIN(520, CGRectGetWidth(self.bounds) - 40);
    self.card = [[UIView alloc] initWithFrame:CGRectMake((CGRectGetWidth(self.bounds) - w) / 2, 100, w, 260)];
    self.card.backgroundColor = [UIColor systemBackgroundColor];
    self.card.layer.cornerRadius = 16;
    self.card.clipsToBounds = YES;
    [self addSubview:self.card];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 16, 160, 24)];
    self.titleLabel.text = @"谱面下载";
    self.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [self.card addSubview:self.titleLabel];

    self.exportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.exportButton setTitle:@"谱面导出" forState:UIControlStateNormal];
    self.exportButton.titleLabel.font = [UIFont systemFontOfSize:15];
    [self.exportButton addTarget:self action:@selector(exportTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:self.exportButton];

    self.subLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.subLabel.text = [NSString stringWithFormat:@"%@ · %@", self.item[@"title"] ?: @"", self.item[@"artist"] ?: @""];
    self.subLabel.font = [UIFont systemFontOfSize:12];
    self.subLabel.textColor = [UIColor secondaryLabelColor];
    self.subLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.card addSubview:self.subLabel];

    self.pill = [[UILabel alloc] initWithFrame:CGRectZero];
    self.pill.text = @"⤓ 站内下载 .zip";
    self.pill.textAlignment = NSTextAlignmentCenter;
    self.pill.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.pill.textColor = [UIColor whiteColor];
    self.pill.backgroundColor = [UIColor colorWithRed:122/255.0 green:114/255.0 blue:240/255.0 alpha:1.0];
    self.pill.layer.cornerRadius = 10;
    self.pill.clipsToBounds = YES;
    [self.card addSubview:self.pill];

    self.srcLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.srcLabel.text = @"来自 majdata.net";
    self.srcLabel.font = [UIFont systemFontOfSize:12];
    self.srcLabel.textColor = [UIColor secondaryLabelColor];
    [self.card addSubview:self.srcLabel];

    self.bgaLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.bgaLabel.text = @"包含 BGA 视频";
    self.bgaLabel.font = [UIFont systemFontOfSize:15];
    [self.card addSubview:self.bgaLabel];

    self.bgaHint = [[UILabel alloc] initWithFrame:CGRectZero];
    self.bgaHint.text = @"只影响背景动画，不影响谱面游玩。";
    self.bgaHint.font = [UIFont systemFontOfSize:11.5];
    self.bgaHint.textColor = [UIColor tertiaryLabelColor];
    [self.card addSubview:self.bgaHint];

    self.bga = [[UISwitch alloc] initWithFrame:CGRectZero];
    self.bga.on = NO;
    [self.card addSubview:self.bga];

    self.bar = [[UIProgressView alloc] initWithFrame:CGRectZero];
    self.bar.progress = 0;
    self.bar.hidden = YES;
    [self.card addSubview:self.bar];

    self.status = [[UILabel alloc] initWithFrame:CGRectZero];
    self.status.font = [UIFont systemFontOfSize:12];
    self.status.textColor = [UIColor secondaryLabelColor];
    self.status.text = @"点下方按钮开始下载";
    [self.card addSubview:self.status];

    self.main = [UIButton buttonWithType:UIButtonTypeSystem];
    self.main.backgroundColor = [UIColor systemBlueColor];
    [self.main setTitle:@"开始下载" forState:UIControlStateNormal];
    [self.main setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.main.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.main.layer.cornerRadius = 10;
    [self.main addTarget:self action:@selector(mainTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:self.main];

    [self layoutCard];
}

- (void)layoutCard
{
    CGFloat w = self.card.bounds.size.width;
    CGFloat pad = 20;
    CGFloat inner = w - pad * 2;

    self.exportButton.frame = CGRectMake(w - pad - 84, 14, 84, 28);
    self.subLabel.frame = CGRectMake(pad, 44, inner, 18);
    self.pill.frame = CGRectMake(pad, 70, 150, 44);
    self.srcLabel.frame = CGRectMake(pad + 162, 82, inner - 162, 18);

    CGFloat y = 126;
    self.bgaLabel.frame = CGRectMake(pad, y + 4, inner - 60, 20);
    self.bgaHint.frame = CGRectMake(pad, y + 26, inner - 60, 16);
    self.bga.frame = CGRectMake(w - pad - 51, y + 4, 51, 31);
    y += 46;

    if (!self.bar.hidden) {
        self.bar.frame = CGRectMake(pad, y + 4, inner, 4);
        self.status.frame = CGRectMake(pad, y + 10, inner, 20);
        y += 36;
    } else {
        self.status.frame = CGRectMake(pad, y + 4, inner, 20);
        y += 28;
    }

    self.main.frame = CGRectMake(pad, y + 8, inner, 44);
    y += 8 + 44;
    y += 20;

    CGRect f = self.card.frame;
    f.size.height = y;
    f.origin.y = MAX(24, round((self.bounds.size.height - y) / 2));
    self.card.frame = f;
}

- (void)mainTapped
{
    if (self.running) {
        self.running = NO;
        self.status.text = @"已取消下载";
        [self.main setTitle:@"开始下载" forState:UIControlStateNormal];
        self.main.backgroundColor = [UIColor systemBlueColor];
        return;
    }
    if (self.folder) return;

    self.running = YES;
    [self.main setTitle:@"取消下载" forState:UIControlStateNormal];
    self.main.backgroundColor = [UIColor systemRedColor];
    self.status.text = @"正在下载…";

    BOOL grew = self.bar.hidden;
    self.bar.hidden = NO;
    if (grew) {
        [UIView animateWithDuration:0.2 animations:^{
            [self layoutCard];
            [self.card layoutIfNeeded];
        }];
    }

    __weak typeof(self) weakSelf = self;
    [ADXMajData download:self.item includeBGA:self.bga.on progress:^(CGFloat ratio, NSString *status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.bar setProgress:ratio animated:YES];
            weakSelf.status.text = status;
        });
    } completion:^(NSString *folder, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.running = NO;
            if (folder.length) {
                weakSelf.folder = folder;
                [weakSelf.bar setProgress:1 animated:YES];
                weakSelf.status.text = [NSString stringWithFormat:@"已导入 levels/%@", [folder lastPathComponent]];
                [weakSelf.main setTitle:@"已导入游戏" forState:UIControlStateNormal];
                weakSelf.main.backgroundColor = [UIColor tertiarySystemFillColor];
                [weakSelf.main setTitleColor:[UIColor secondaryLabelColor] forState:UIControlStateNormal];
                weakSelf.main.enabled = NO;
            } else {
                weakSelf.status.text = error.localizedDescription ?: @"下载失败";
                [weakSelf.main setTitle:@"重新下载" forState:UIControlStateNormal];
                weakSelf.main.backgroundColor = [UIColor systemBlueColor];
            }
        });
    }];
}

- (void)exportTapped
{
    if (!self.folder.length) {
        self.status.text = @"先下载，再导出 zip";
        return;
    }
    NSString *zip = [NSTemporaryDirectory() stringByAppendingPathComponent:
                     [[self.folder lastPathComponent] stringByAppendingString:@".zip"]];
    [[NSFileManager defaultManager] removeItemAtPath:zip error:nil];
    NSError *err = nil;
    if (![ADXZip zipDirectory:self.folder to:zip error:&err]) {
        self.status.text = @"打包失败";
        return;
    }
    UIActivityViewController *ac = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:zip]]
                                                                    applicationActivities:nil];
    UIViewController *host = self.window.rootViewController;
    while (host.presentedViewController) host = host.presentedViewController;
    ac.popoverPresentationController.sourceView = self.main;
    [host presentViewController:ac animated:YES completion:nil];
}

- (void)close
{
    [UIView animateWithDuration:0.15 animations:^{ self.alpha = 0; } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end
