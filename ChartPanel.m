// ChartPanel.m — 谱面查询：输入关键词 → 候选列表 → 曲目详情（曲绘 / 编号 / 别名 / 难度谱面）
#import "ChartPanel.h"
#import "ChartDb.h"
#import "ChartDetailSheet.h"
#import "ChartFav.h"
#import "ChartDownloadSheet.h"
#import "B50Image.h"

static UIColor *ARGB(CGFloat r, CGFloat g, CGFloat b)
{
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}

static NSString *DiffName(NSInteger d)
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

static UIColor *Darken(UIColor *c, CGFloat k)
{
    CGFloat r = 0, g = 0, b = 0, a = 1;
    if (![c getRed:&r green:&g blue:&b alpha:&a]) return c;
    return [UIColor colorWithRed:r * k green:g * k blue:b * k alpha:a];
}

static UIColor *DiffColor(NSInteger d)
{
    switch (d) {
        case 0: return ARGB(66, 168, 92);
        case 1: return ARGB(232, 158, 44);
        case 2: return ARGB(214, 74, 88);
        case 3: return ARGB(150, 92, 214);
        case 4: return ARGB(236, 236, 244);
        default: return ARGB(150, 92, 214);
    }
}

// 难度条本身可点，弹出「谱面详情」，所以让它自带一份数据
@interface ADXBarView : UIView
@property (nonatomic, strong) NSArray *song;
@property (nonatomic, strong) NSArray *chart;
@property (nonatomic, assign) BOOL isDx;
@property (nonatomic, copy) NSString *version;
@end

@implementation ADXBarView
@end

@interface ADXChartPanel () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UITableView *suggest;
@property (nonatomic, strong) UIScrollView *detail;
@property (nonatomic, strong) UIView *emptyView;

@property (nonatomic, copy) NSArray *hits;
@property (nonatomic, copy) NSArray *song;
@property (nonatomic, assign) NSInteger typeIndex;   // 0 标准 · 1 DX
@property (nonatomic, strong) UIButton *favButton;

@end

@implementation ADXChartPanel

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor systemGroupedBackgroundColor];
        [self buildUI];
    }
    return self;
}

#pragma mark - 界面

- (void)buildUI
{
    self.search = [[UISearchBar alloc] initWithFrame:CGRectZero];
    self.search.placeholder = @"请选择曲目";
    self.search.searchBarStyle = UISearchBarStyleMinimal;
    self.search.delegate = self;
    self.search.autocorrectionType = UITextAutocorrectionTypeNo;
    self.search.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [self addSubview:self.search];

    self.hintLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.hintLabel.numberOfLines = 2;
    self.hintLabel.attributedText = [self hintText];
    [self addSubview:self.hintLabel];

    self.suggest = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.suggest.dataSource = self;
    self.suggest.delegate = self;
    self.suggest.rowHeight = 58;
    self.suggest.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.suggest.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16);
    self.suggest.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.suggest.layer.cornerRadius = 12;
    self.suggest.layer.masksToBounds = YES;
    self.suggest.layer.borderWidth = 0.5;
    self.suggest.layer.borderColor = [UIColor separatorColor].CGColor;
    self.suggest.hidden = YES;
    [self addSubview:self.suggest];

    self.detail = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.detail.alwaysBounceVertical = YES;
    self.detail.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.detail.hidden = YES;
    [self addSubview:self.detail];

    [self buildEmptyView];
}

- (NSAttributedString *)hintText
{
    NSString *s = @"你可以使用曲目 ID、曲名、艺术家或曲目别名来搜索曲目。";
    return [[NSAttributedString alloc] initWithString:s
                                          attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12.5],
                                                       NSForegroundColorAttributeName: [UIColor secondaryLabelColor]}];
}

- (void)buildEmptyView
{
    self.emptyView = [[UIView alloc] initWithFrame:CGRectZero];

    UIImage *icon = [UIImage systemImageNamed:@"list.bullet.rectangle"];
    UIImageView *iv = [[UIImageView alloc] initWithImage:icon];
    iv.tintColor = [UIColor tertiaryLabelColor];
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.tag = 901;
    [self.emptyView addSubview:iv];

    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.text = @"请选择一首曲目来查看曲目详情";
    l.font = [UIFont systemFontOfSize:14];
    l.textColor = [UIColor secondaryLabelColor];
    l.textAlignment = NSTextAlignmentCenter;
    l.tag = 902;
    [self.emptyView addSubview:l];

    // 还没选歌时也能直接进收藏夹
    UIButton *fav = [UIButton buttonWithType:UIButtonTypeSystem];
    [fav setTitle:@"收藏夹" forState:UIControlStateNormal];
    fav.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [fav setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    fav.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    fav.layer.cornerRadius = 10;
    fav.layer.borderWidth = 0.5;
    fav.layer.borderColor = [UIColor separatorColor].CGColor;
    fav.tag = 903;
    [fav addTarget:self action:@selector(openFavorites) forControlEvents:UIControlEventTouchUpInside];
    [self.emptyView addSubview:fav];

    [self addSubview:self.emptyView];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat W = self.bounds.size.width;
    CGFloat H = self.bounds.size.height;

    self.search.frame = CGRectMake(8, 4, W - 16, 46);
    CGFloat hy = CGRectGetMaxY(self.search.frame) - 4;
    CGSize hs = [self.hintLabel sizeThatFits:CGSizeMake(W - 32, 60)];
    self.hintLabel.frame = CGRectMake(16, hy, W - 32, hs.height);

    CGFloat top = CGRectGetMaxY(self.hintLabel.frame) + 8;
    self.detail.frame = CGRectMake(0, top, W, MAX(0, H - top));
    self.emptyView.frame = self.detail.frame;

    UIView *icon = [self.emptyView viewWithTag:901];
    UILabel *tip = (UILabel *)[self.emptyView viewWithTag:902];
    UIButton *favBtn = (UIButton *)[self.emptyView viewWithTag:903];
    CGFloat cy = CGRectGetMidY(self.emptyView.bounds) - 60;
    icon.frame = CGRectMake((W - 44) / 2, cy, 44, 44);
    tip.frame = CGRectMake(16, cy + 60, W - 32, 22);
    favBtn.frame = CGRectMake((W - 128) / 2, cy + 92, 128, 38);

    CGFloat sh = MIN(self.hits.count * 58.0, 320.0);
    self.suggest.frame = CGRectMake(16, CGRectGetMaxY(self.search.frame) - 3, W - 32, sh);
}

- (void)refreshVisibility
{
    BOOL hasHits = self.hits.count > 0;
    self.suggest.hidden = !hasHits;
    self.hintLabel.hidden = hasHits;          // 候选浮层出现时收起提示，避免被压住半行
    self.emptyView.hidden = (self.song != nil) || hasHits;
    self.detail.hidden = (self.song == nil);
    if (hasHits) [self bringSubviewToFront:self.suggest];
}

#pragma mark - 搜索

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    NSString *q = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.hits = q.length ? [ADXChartDb search:q limit:40] : @[];

    [self.suggest reloadData];
    [self setNeedsLayout];
    [self refreshVisibility];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

#pragma mark - 候选列表

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.hits.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"hit"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"hit"];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.5];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }

    NSArray *s = self.hits[indexPath.row];
    cell.textLabel.text = s[1];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", s[2], [ADXChartDb numberText:s]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSArray *s = self.hits[indexPath.row];
    self.hits = @[];
    [self.suggest reloadData];
    [self.search resignFirstResponder];

    [self showSong:s];
    [self refreshVisibility];
}

#pragma mark - 曲目详情

- (void)showSong:(NSArray *)song
{
    self.song = song;
    self.typeIndex = [ADXChartDb hasDx:song] ? 1 : 0;
    [self rebuildDetail];
}

- (void)showSongById:(int)songId
{
    NSArray *s = [ADXChartDb songById:songId];
    if (!s) return;

    self.hits = @[];
    [self.suggest reloadData];
    [self.search resignFirstResponder];
    self.search.text = s[1];

    [self showSong:s];
    [self refreshVisibility];
    [self.detail setContentOffset:CGPointZero animated:NO];
}

- (void)rebuildDetail
{
    for (UIView *v in [self.detail.subviews copy]) [v removeFromSuperview];

    NSArray *song = self.song;
    if (!song) return;

    CGFloat W = self.bounds.size.width - 32;
    CGFloat x = 16;
    CGFloat y0 = 4;
    CGFloat y = y0 + 12;

    // 曲绘
    CGFloat coverSide = 84;
    UIImageView *cover = [[UIImageView alloc] initWithFrame:CGRectMake(x + 8, y, coverSide, coverSide)];
    cover.backgroundColor = [UIColor secondarySystemBackgroundColor];
    cover.contentMode = UIViewContentModeScaleAspectFill;
    cover.layer.cornerRadius = 8;
    cover.layer.masksToBounds = YES;
    cover.tag = [ADXChartDb displayId:song];
    [self.detail addSubview:cover];
    [self loadCover:[song[0] intValue] song:song into:cover];

    // 编号
    CGFloat tx = x + 8 + coverSide + 14;
    CGFloat tw = W - coverSide - 22 - 44;   // 右侧给收藏星让出位置

    UILabel *no = [[UILabel alloc] initWithFrame:CGRectZero];
    no.text = [ADXChartDb numberText:song];
    no.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    no.textColor = [UIColor secondaryLabelColor];
    no.textAlignment = NSTextAlignmentCenter;
    no.backgroundColor = [UIColor secondarySystemBackgroundColor];
    no.layer.cornerRadius = 11;
    no.layer.masksToBounds = YES;
    [no sizeToFit];
    no.frame = CGRectMake(tx, y + 2, no.bounds.size.width + 26, 22);
    [self.detail addSubview:no];
    [self copyable:no];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(tx, y + 28, tw, 46)];
    title.text = song[1];
    title.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    title.numberOfLines = 2;
    [self.detail addSubview:title];

    CGSize ts = [title.text boundingRectWithSize:CGSizeMake(tw, 46)
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:@{NSFontAttributeName: title.font}
                                         context:nil].size;
    CGFloat th = MAX(24, MIN(46, ceil(ts.height)));
    title.frame = CGRectMake(tx, y + 28, tw, th);
    [self copyable:title];

    UILabel *artist = [[UILabel alloc] initWithFrame:CGRectMake(tx, y + 30 + th, tw, 20)];
    artist.text = song[2];
    artist.font = [UIFont systemFontOfSize:14];
    artist.textColor = [UIColor secondaryLabelColor];
    [self.detail addSubview:artist];
    [self copyable:artist];

    y += MAX(coverSide, 30 + th + 20) + 22;

    // BPM / 分类 / 首次出现版本（版本和分类要写国服/日服两段，列宽按 20% / 30% / 50% 分）
    NSArray *titles = @[@"BPM", @"分类", @"首次出现版本"];
    NSArray *values = @[[NSString stringWithFormat:@"%@", song[4]],
                        [ADXChartDb genreText:song],
                        [ADXChartDb versionText:song dx:(self.typeIndex == 1)]];
    CGFloat inner = W - 32;
    CGFloat frac[3] = {0.16, 0.36, 0.48};
    CGFloat cx = x + 8;
    for (int i = 0; i < 3; i++) {
        CGFloat colW = floor(inner * frac[i]);
        UILabel *cap = [[UILabel alloc] initWithFrame:CGRectMake(cx, y, colW, 16)];
        cap.text = titles[i];
        cap.font = [UIFont systemFontOfSize:11.5];
        cap.textColor = [UIColor tertiaryLabelColor];
        [self.detail addSubview:cap];

        UILabel *val = [[UILabel alloc] initWithFrame:CGRectMake(cx, y + 17, colW - 6, 20)];
        val.text = values[i];
        val.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        val.adjustsFontSizeToFitWidth = YES;
        val.minimumScaleFactor = 0.6;
        val.lineBreakMode = NSLineBreakByClipping;
        [self.detail addSubview:val];
        [self copyable:val];

        cx += colW;
    }
    y += 46;

    // 曲目别名
    NSArray *aliases = song[7];
    UILabel *alTitle = [[UILabel alloc] initWithFrame:CGRectMake(x + 8, y, W - 32, 16)];
    alTitle.text = @"曲目别名";
    alTitle.font = [UIFont systemFontOfSize:11.5];
    alTitle.textColor = [UIColor tertiaryLabelColor];
    [self.detail addSubview:alTitle];
    y += 20;

    if (aliases.count) {
        y += [self layoutChips:aliases x:x + 8 y:y maxWidth:W - 32];
    } else {
        UILabel *none = [[UILabel alloc] initWithFrame:CGRectMake(x + 8, y, W - 32, 20)];
        none.text = @"暂无别名";
        none.font = [UIFont systemFontOfSize:13];
        none.textColor = [UIColor tertiaryLabelColor];
        [self.detail addSubview:none];
        y += 20;
    }

    // 信息区外圈细线（画在元素之下，不改变任何元素的位置）
    CGFloat infoBottom = y + 6;
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(x - 8, y0, W + 16, infoBottom - y0)];
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 12;
    card.layer.borderWidth = 0.5;
    card.layer.borderColor = [UIColor separatorColor].CGColor;
    [self.detail insertSubview:card atIndex:0];

    // 右上角收藏星
    UIButton *star = [UIButton buttonWithType:UIButtonTypeSystem];
    star.frame = CGRectMake(CGRectGetMaxX(card.frame) - 40, y0 + 8, 30, 30);
    star.tintColor = [UIColor tertiaryLabelColor];
    [star addTarget:self action:@selector(toggleFav) forControlEvents:UIControlEventTouchUpInside];
    [self.detail addSubview:star];
    self.favButton = star;
    [self refreshFavButton];

    y = infoBottom + 10;

    // 标准 / DX
    BOOL hasStd = [(NSArray *)song[8] count] > 0;
    BOOL hasDx = [ADXChartDb hasDx:song];
    if (hasStd && hasDx) {
        UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"标准", @"DX"]];
        seg.selectedSegmentIndex = self.typeIndex;
        CGFloat sw = MIN(160, W - 16);
        seg.frame = CGRectMake(round((self.bounds.size.width - sw) / 2), y, sw, 30);
        [seg addTarget:self action:@selector(typeChanged:) forControlEvents:UIControlEventValueChanged];
        [self.detail addSubview:seg];
        y += 38;
    } else {
        UILabel *tag = [[UILabel alloc] initWithFrame:CGRectZero];
        tag.text = hasDx ? @"DX" : @"标准";
        tag.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        tag.textColor = [UIColor whiteColor];
        tag.backgroundColor = hasDx ? ARGB(214, 74, 88) : [UIColor systemBlueColor];
        tag.textAlignment = NSTextAlignmentCenter;
        tag.layer.cornerRadius = 11;
        tag.layer.masksToBounds = YES;
        [tag sizeToFit];
        CGFloat tagW = tag.bounds.size.width + 28;   // 左右各留 14，不用空格撑宽（空格会被裁掉导致偏右）
        tag.frame = CGRectMake(round((self.bounds.size.width - tagW) / 2), y, tagW, 22);
        [self.detail addSubview:tag];
        y += 30;
    }

    // 难度谱面
    NSArray *charts = [ADXChartDb chartsOf:song dx:(self.typeIndex == 1)];
    NSString *barVersion = [ADXChartDb versionText:song dx:(self.typeIndex == 1)];
    for (NSArray *c in charts) {
        UIView *bar = [self barForChart:c
                                   song:song
                                     dx:(self.typeIndex == 1)
                                version:barVersion
                                  width:W - 32];
        bar.frame = CGRectMake(x + 8, y, W - 32, 64);
        [self.detail addSubview:bar];
        y += 64 + 10;
    }

    if (!charts.count) {
        UILabel *none = [[UILabel alloc] initWithFrame:CGRectMake(x + 8, y, W - 32, 20)];
        none.text = @"这一边没有谱面";
        none.font = [UIFont systemFontOfSize:13];
        none.textColor = [UIColor tertiaryLabelColor];
        [self.detail addSubview:none];
        y += 26;
    }

    // 收藏夹 / 谱面下载
    y += 6;
    CGFloat btnW = (W - 32 - 12) / 2;
    UIButton *favBtn = [self pillButton:@"收藏夹" frame:CGRectMake(x + 8, y, btnW, 44)];
    [favBtn addTarget:self action:@selector(openFavorites) forControlEvents:UIControlEventTouchUpInside];
    [self.detail addSubview:favBtn];

    UIButton *dlBtn = [self pillButton:@"谱面下载" frame:CGRectMake(x + 8 + btnW + 12, y, btnW, 44)];
    [dlBtn addTarget:self action:@selector(openDownload) forControlEvents:UIControlEventTouchUpInside];
    [self.detail addSubview:dlBtn];
    y += 44;

    self.detail.contentSize = CGSizeMake(self.bounds.size.width, y + 24);
}

- (UIButton *)pillButton:(NSString *)title frame:(CGRect)frame
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = frame;
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    b.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    [b setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    b.layer.cornerRadius = 10;
    b.layer.borderWidth = 0.5;
    b.layer.borderColor = [UIColor separatorColor].CGColor;
    return b;
}

#pragma mark - 收藏 / 下载

- (void)refreshFavButton
{
    int sid = [self.song[0] intValue];
    BOOL on = [ADXChartFav contains:sid];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:16
                                                                                   weight:UIImageSymbolWeightMedium];
    UIImage *img = [UIImage systemImageNamed:(on ? @"star.fill" : @"star") withConfiguration:cfg];
    [self.favButton setImage:img forState:UIControlStateNormal];
    self.favButton.tintColor = on ? [UIColor systemYellowColor] : [UIColor tertiaryLabelColor];
}

- (void)toggleFav
{
    int sid = [self.song[0] intValue];
    BOOL on = [ADXChartFav toggle:sid];
    [self refreshFavButton];
    [self toast:(on ? @"已收藏" : @"已取消收藏")];
}

- (void)openFavorites
{
    __weak __typeof(self) weakSelf = self;
    [ADXChartFavSheet presentInView:self.window open:^(int songId) {
        [weakSelf showSongById:songId];
    }];
}

- (void)openDownload
{
    [ADXChartDownloadSheet presentSong:self.song dx:(self.typeIndex == 1) inView:self.window];
}

- (void)typeChanged:(UISegmentedControl *)seg
{
    self.typeIndex = seg.selectedSegmentIndex;
    [self rebuildDetail];
}

#pragma mark - 长按复制

- (void)copyable:(UIView *)v
{
    if (!v) return;
    v.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *g =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressCopy:)];
    g.minimumPressDuration = 0.45;
    [v addGestureRecognizer:g];
}

- (void)longPressCopy:(UILongPressGestureRecognizer *)g
{
    if (g.state != UIGestureRecognizerStateBegan) return;

    NSString *text = nil;
    if ([g.view isKindOfClass:[UILabel class]]) {
        UILabel *l = (UILabel *)g.view;
        text = l.text.length ? l.text : l.attributedText.string;
    }
    if (!text.length) return;

    [UIPasteboard generalPasteboard].string = text;
    [self toast:[NSString stringWithFormat:@"已复制：%@", text]];
}

- (void)toast:(NSString *)msg
{
    UIView *host = self.window ?: self;

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectZero];
    t.text = msg;
    t.font = [UIFont systemFontOfSize:13];
    t.textColor = [UIColor whiteColor];
    t.backgroundColor = [UIColor colorWithWhite:0 alpha:0.82];
    t.textAlignment = NSTextAlignmentCenter;
    t.lineBreakMode = NSLineBreakByTruncatingMiddle;
    t.layer.cornerRadius = 15;
    t.layer.masksToBounds = YES;

    CGFloat maxW = host.bounds.size.width - 80;
    CGSize s = [t sizeThatFits:CGSizeMake(maxW, 30)];
    CGFloat w = MIN(maxW, s.width + 30);
    t.frame = CGRectMake(round((host.bounds.size.width - w) / 2),
                         CGRectGetMaxY(host.bounds) - 104, w, 30);
    t.alpha = 0;
    [host addSubview:t];

    __weak UILabel *weakT = t;
    [UIView animateWithDuration:0.15
                     animations:^{
        weakT.alpha = 1;
    }
                     completion:^(BOOL ok) {
        [UIView animateWithDuration:0.25
                              delay:1.0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            weakT.alpha = 0;
        }
                         completion:^(BOOL done) {
            [weakT removeFromSuperview];
        }];
    }];
}

#pragma mark - 难度条 → 谱面详情

- (void)tapBar:(UITapGestureRecognizer *)g
{
    if (g.state != UIGestureRecognizerStateEnded) return;

    ADXBarView *bar = (ADXBarView *)g.view;
    if (![bar isKindOfClass:[ADXBarView class]]) return;

    UIView *host = self.window ?: self;
    [ADXChartSheet presentSong:bar.song
                         chart:bar.chart
                            dx:bar.isDx
                       version:bar.version
                      coverDir:self.coverDir
                        inView:host];
}

- (UIView *)barForChart:(NSArray *)chart
                   song:(NSArray *)song
                     dx:(BOOL)isDx
                version:(NSString *)version
                  width:(CGFloat)W
{
    NSInteger d = [chart[0] integerValue];
    NSString *level = [ADXChartDb levelTextOfChart:chart];
    NSString *designer = [ADXChartDb designerOfChart:chart];

    BOOL light = (d == 4);
    UIColor *ink = light ? ARGB(52, 50, 66) : [UIColor whiteColor];
    UIColor *base = DiffColor(d);
    UIColor *edge = Darken(base, 0.74);

    ADXBarView *bar = [[ADXBarView alloc] initWithFrame:CGRectMake(0, 0, W, 64)];
    bar.song = song;
    bar.chart = chart;
    bar.isDx = isDx;
    bar.version = version;
    bar.userInteractionEnabled = YES;
    [bar addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapBar:)]];
    bar.backgroundColor = base;
    bar.layer.cornerRadius = 10;
    bar.layer.borderWidth = 1.0;
    bar.layer.borderColor = edge.CGColor;
    bar.layer.masksToBounds = YES;

    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 31.5, W, 0.5)];
    line.backgroundColor = edge;
    [bar addSubview:line];

    NSMutableAttributedString *top =
        [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ ", DiffName(d)]
                                               attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold],
                                                            NSForegroundColorAttributeName: [ink colorWithAlphaComponent:0.92]}];
    [top appendAttributedString:[[NSAttributedString alloc] initWithString:(level.length ? level : @"")
                                                               attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:19 weight:UIFontWeightBold],
                                                                            NSForegroundColorAttributeName: ink}]];

    UILabel *topLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 7, W - 28, 24)];
    topLabel.attributedText = top;
    [bar addSubview:topLabel];

    UIFont *capF = [UIFont systemFontOfSize:12];
    UIFont *valF = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    UIColor *capC = [ink colorWithAlphaComponent:0.72];

    NSMutableAttributedString *sub = [[NSMutableAttributedString alloc] init];
    if (designer.length) {
        [sub appendAttributedString:[[NSAttributedString alloc] initWithString:@"谱师 "
                                                                   attributes:@{NSFontAttributeName: capF,
                                                                                NSForegroundColorAttributeName: capC}]];
        [sub appendAttributedString:[[NSAttributedString alloc] initWithString:designer
                                                                   attributes:@{NSFontAttributeName: valF,
                                                                                NSForegroundColorAttributeName: ink}]];
    }
    if (version.length) {
        if (sub.length)
            [sub appendAttributedString:[[NSAttributedString alloc] initWithString:@"    "
                                                                       attributes:@{NSFontAttributeName: capF,
                                                                                    NSForegroundColorAttributeName: capC}]];
        [sub appendAttributedString:[[NSAttributedString alloc] initWithString:@"版本 "
                                                                   attributes:@{NSFontAttributeName: capF,
                                                                                NSForegroundColorAttributeName: capC}]];
        [sub appendAttributedString:[[NSAttributedString alloc] initWithString:version
                                                                   attributes:@{NSFontAttributeName: valF,
                                                                                NSForegroundColorAttributeName: ink}]];
    }

    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 38, W - 28, 18)];
    subLabel.attributedText = sub;
    subLabel.adjustsFontSizeToFitWidth = YES;
    subLabel.minimumScaleFactor = 0.85;
    [bar addSubview:subLabel];

    // 谱师 / 版本 各自一块透明热区：长按复制，轻点仍然是点整条弹窗
    CGFloat avail = W - 28;
    CGFloat wCap1 = ceil([@"谱师 " sizeWithAttributes:@{NSFontAttributeName: capF}].width);
    CGFloat wVal1 = designer.length ? ceil([designer sizeWithAttributes:@{NSFontAttributeName: valF}].width) : 0;
    CGFloat wCap2 = version.length ? ceil([@"版本 " sizeWithAttributes:@{NSFontAttributeName: capF}].width) : 0;
    CGFloat wVal2 = version.length ? ceil([version sizeWithAttributes:@{NSFontAttributeName: valF}].width) : 0;

    CGFloat adv1 = 22;                       // 版本前的间隔（"    " 四个空格）
    CGFloat total = wCap1 + wVal1 + (version.length ? adv1 + wCap2 + wVal2 : 0);
    CGFloat k = (total > avail && total > 0) ? avail / total : 1.0;

    CGFloat hx = 14;
    if (designer.length) {
        [self copyZone:CGRectMake(hx + wCap1 * k, 38, MAX(10, wVal1 * k), 18) text:designer in:bar];
        hx += (wCap1 + wVal1) * k;
    }
    if (version.length) {
        hx += adv1 * k;
        [self copyZone:CGRectMake(hx + wCap2 * k, 38, MAX(10, wVal2 * k), 18) text:version in:bar];
    }

    return bar;
}

/// 在难度条上叠一块只有文字看不见的热区，长按复制该文字
- (void)copyZone:(CGRect)rect text:(NSString *)text in:(UIView *)bar
{
    if (!text.length) return;

    UILabel *z = [[UILabel alloc] initWithFrame:rect];
    z.text = text;
    z.font = [UIFont systemFontOfSize:12];
    z.textColor = [UIColor clearColor];      // 透明但可点：alpha 不能为 0，否则不参与命中测试
    z.userInteractionEnabled = YES;

    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressCopy:)];
    lp.minimumPressDuration = 0.45;
    [z addGestureRecognizer:lp];

    // 长按已经触发时，不要再把这次操作当成「点开谱面详情」
    for (UIGestureRecognizer *g in bar.gestureRecognizers)
        if ([g isKindOfClass:[UITapGestureRecognizer class]]) [g requireGestureRecognizerToFail:lp];

    [bar addSubview:z];
}

- (CGFloat)layoutChips:(NSArray *)chips x:(CGFloat)x y:(CGFloat)y maxWidth:(CGFloat)maxW
{
    CGFloat cx = x, cy = y;
    CGFloat h = 27, pad = 10, gap = 8;
    UIFont *f = [UIFont systemFontOfSize:13];

    for (id a in chips) {
        if (![a isKindOfClass:[NSString class]]) continue;
        NSString *t = a;
        CGFloat tw = ceil([t sizeWithAttributes:@{NSFontAttributeName: f}].width);
        CGFloat w = MIN(tw + pad * 2, maxW);

        if (cx + w > x + maxW && cx > x) {
            cx = x;
            cy += h + gap;
        }

        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(cx, cy, w, h)];
        l.text = t;
        l.font = f;
        l.textAlignment = NSTextAlignmentCenter;
        l.textColor = [UIColor labelColor];
        l.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        l.layer.cornerRadius = 8;
        l.layer.borderWidth = 0.5;
        l.layer.borderColor = [UIColor separatorColor].CGColor;
        l.layer.masksToBounds = YES;
        l.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.detail addSubview:l];
        [self copyable:l];

        cx += w + gap;
    }

    return (cy - y) + h;
}

- (void)loadCover:(int)songId song:(NSArray *)song into:(UIImageView *)iv
{
    NSString *dir = self.coverDir.length ? self.coverDir
                   : [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/covers"];
    NSString *url = [ADXChartDb coverURL:song];
    NSInteger expect = iv.tag;
    __weak UIImageView *weakIV = iv;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *img = url.length ? [ADXImage coverImageFor:songId url:url dir:dir]
                                  : [ADXImage coverImageFor:songId dir:dir];
        if (!img) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakIV && weakIV.tag == expect) weakIV.image = img;
        });
    });
}

@end
