// ChartFav.m — 收藏夹存储 + 收藏夹弹窗（资源管理式多选：选择/完成、全选、删除、刷新、长按拖动）
#import "ChartFav.h"
#import "ChartDb.h"
#import "B50Image.h"

static NSString *const kFavKey = @"adx.favs";

static NSString *FavCoverDir(void)
{
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/covers"];
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
    CGFloat right = self.accessoryView ? 40 : 16;
    self.name.frame = CGRectMake(64, 9, w - 64 - right, 19);
    self.sub.frame = CGRectMake(64, 28, w - 64 - right, 17);
}

- (void)setChecked:(BOOL)on selecting:(BOOL)selecting
{
    if (!selecting) {
        self.check.hidden = YES;
        self.accessoryView = nil;
        return;
    }
    self.check.hidden = NO;
    self.accessoryView = self.check;
    self.check.image = [UIImage systemImageNamed:(on ? @"checkmark.circle.fill" : @"circle")];
    self.check.tintColor = on ? [UIColor systemBlueColor] : [UIColor tertiaryLabelColor];
}

@end

#pragma mark - 弹窗

@interface ADXChartFavSheet () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIView *dim;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UILabel *empty;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *selectButton;
@property (nonatomic, strong) UIButton *allButton;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *refreshButton;
@property (nonatomic, strong) UIButton *deleteButton;

@property (nonatomic, copy) NSArray *all;              // 收藏的全部曲目
@property (nonatomic, copy) NSArray *songs;            // 当前显示（搜索过滤后）
@property (nonatomic, strong) NSMutableSet *picked;    // 选中的 songId
@property (nonatomic, assign) BOOL selecting;
@property (nonatomic, assign) NSInteger dragStart;
@property (nonatomic, copy) void (^openBlock)(int songId);
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

    // 右上角：关闭 / 全选 / 选择
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(w - 66, 0, 50, 50);
    [close setTitle:@"关闭" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:15];
    [close addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:close];
    self.closeButton = close;

    UIButton *all = [UIButton buttonWithType:UIButtonTypeSystem];
    all.frame = CGRectMake(w - 128, 0, 58, 50);
    [all setTitle:@"全选" forState:UIControlStateNormal];
    all.titleLabel.font = [UIFont systemFontOfSize:15];
    all.hidden = YES;
    [all addTarget:self action:@selector(toggleAll) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:all];
    self.allButton = all;

    UIButton *sel = [UIButton buttonWithType:UIButtonTypeSystem];
    sel.frame = CGRectMake(w - 190, 0, 58, 50);
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

    UIButton *refresh = [UIButton buttonWithType:UIButtonTypeSystem];
    refresh.frame = CGRectMake(0, 6, w / 2, 40);
    [refresh setTitle:@"刷新" forState:UIControlStateNormal];
    refresh.titleLabel.font = [UIFont systemFontOfSize:15];
    [refresh addTarget:self action:@selector(refreshTapped) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:refresh];
    self.refreshButton = refresh;

    UIButton *del = [UIButton buttonWithType:UIButtonTypeSystem];
    del.frame = CGRectMake(w / 2, 6, w / 2, 40);
    [del setTitle:@"删除" forState:UIControlStateNormal];
    del.titleLabel.font = [UIFont systemFontOfSize:15];
    [del setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    [del addTarget:self action:@selector(deleteTapped) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:del];
    self.deleteButton = del;

    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 50, w, h - 50)
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

    UILabel *empty = [[UILabel alloc] initWithFrame:CGRectMake(0, 130, w, 24)];
    empty.font = [UIFont systemFontOfSize:14];
    empty.textColor = [UIColor tertiaryLabelColor];
    empty.textAlignment = NSTextAlignmentCenter;
    [card addSubview:empty];
    self.empty = empty;

    [self reloadFavs];
    [self refreshHeader];
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
    self.songs = list;
    [self.table reloadData];

    self.empty.hidden = (list.count > 0);
    self.empty.text = @"还没有收藏的曲目";
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
    if (!on) [self.picked removeAllObjects];

    CGFloat w = self.card.bounds.size.width;
    CGFloat h = self.card.bounds.size.height;
    CGFloat barH = on ? 50 : 0;

    self.bottomBar.hidden = !on;
    self.bottomBar.frame = CGRectMake(0, h - barH, w, barH);
    self.table.frame = CGRectMake(0, 50, w, h - 50 - barH);
    self.table.allowsMultipleSelection = NO;
    [self.table reloadData];
    [self refreshHeader];
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
    [self.table reloadData];
    [self refreshHeader];
}

- (void)refreshTapped
{
    [self reloadFavs];
    if (self.selecting) {
        [self.picked removeAllObjects];
        [self refreshHeader];
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

        [self.picked removeAllObjects];
        [self.picked addObject:self.songs[ip.row][0]];
        [self.table reloadData];
        [self refreshHeader];
        self.dragStart = ip.row;
        return;
    }

    if (g.state == UIGestureRecognizerStateChanged) {
        if (!self.selecting) return;
        NSIndexPath *ip = [self.table indexPathForRowAtPoint:p];
        if (!ip) return;

        NSInteger a = MIN(self.dragStart, ip.row);
        NSInteger b = MAX(self.dragStart, ip.row);
        [self.picked removeAllObjects];
        for (NSInteger i = a; i <= b && i < (NSInteger)self.songs.count; i++) {
            if (i >= 0) [self.picked addObject:self.songs[i][0]];
        }
        [self.table reloadData];
        [self refreshHeader];
    }
}

#pragma mark - 表格

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.songs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ADXFavCell *cell = [tableView dequeueReusableCellWithIdentifier:@"fav"];
    if (!cell) cell = [[ADXFavCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"fav"];

    NSArray *s = self.songs[indexPath.row];
    cell.name.text = s[1];
    cell.sub.text = [NSString stringWithFormat:@"%@ · %@", s[2], [ADXChartDb numberText:s]];
    [cell setChecked:[self.picked containsObject:s[0]] selecting:self.selecting];

    int sid = [s[0] intValue];
    NSString *url = [ADXChartDb coverURL:s];
    cell.cover.image = nil;
    cell.cover.tag = sid;

    __weak ADXFavCell *weakCell = cell;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *img = url.length ? [ADXImage coverImageFor:sid url:url dir:FavCoverDir()]
                                  : [ADXImage coverImageFor:sid dir:FavCoverDir()];
        if (!img) return;
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

    NSArray *s = self.songs[indexPath.row];
    [ADXChartFav toggle:[s[0] intValue]];
    [self reloadFavs];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSArray *s = self.songs[indexPath.row];
    if (self.selecting) {
        id key = s[0];
        if ([self.picked containsObject:key]) [self.picked removeObject:key];
        else [self.picked addObject:key];
        [tableView reloadData];
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
    __weak __typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.15 animations:^{ weakSelf.alpha = 0; } completion:^(BOOL done) {
        [weakSelf removeFromSuperview];
    }];
}

@end
