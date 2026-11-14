// ChartFav.m — 收藏夹存储 + 收藏夹弹窗（带搜索）
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

@end

#pragma mark - 行

@interface ADXFavCell : UITableViewCell
@property (nonatomic, strong) UIImageView *cover;
@property (nonatomic, strong) UILabel *name;
@property (nonatomic, strong) UILabel *sub;
@end

@implementation ADXFavCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;

        _cover = [[UIImageView alloc] initWithFrame:CGRectMake(20, 10, 38, 38)];
        _cover.contentMode = UIViewContentModeScaleAspectFill;
        _cover.clipsToBounds = YES;
        _cover.layer.cornerRadius = 5;
        _cover.backgroundColor = [UIColor secondarySystemBackgroundColor];
        [self.contentView addSubview:_cover];

        _name = [[UILabel alloc] initWithFrame:CGRectMake(68, 9, 340, 19)];
        _name.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightSemibold];
        _name.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_name];

        _sub = [[UILabel alloc] initWithFrame:CGRectMake(68, 28, 340, 17)];
        _sub.font = [UIFont systemFontOfSize:11.5];
        _sub.textColor = [UIColor secondaryLabelColor];
        _sub.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_sub];

        UIImageView *arrow = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
        arrow.tintColor = [UIColor tertiaryLabelColor];
        arrow.frame = CGRectMake(0, 0, 12, 14);
        self.accessoryView = arrow;
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    self.name.frame = CGRectMake(68, 9, w - 68 - 34, 19);
    self.sub.frame = CGRectMake(68, 28, w - 68 - 34, 17);
}

@end

#pragma mark - 弹窗

@interface ADXChartFavSheet () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UIView *dim;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic, strong) UILabel *empty;
@property (nonatomic, copy) NSArray *all;
@property (nonatomic, copy) NSArray *songs;
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
    NSMutableArray *list = [NSMutableArray array];
    for (NSNumber *n in [ADXChartFav ids]) {
        NSArray *s = [ADXChartDb songById:[n intValue]];
        if (s) [list addObject:s];
    }
    self.all = list;
    self.songs = list;

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

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, w - 80, 50)];
    title.text = @"收藏夹";
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    [card addSubview:title];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(w - 72, 0, 56, 50);
    [close setTitle:@"关闭" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:15];
    [close addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:close];

    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 49.5, w, 0.5)];
    line.backgroundColor = [UIColor separatorColor];
    [card addSubview:line];

    // 搜索框
    UISearchBar *search = [[UISearchBar alloc] initWithFrame:CGRectMake(12, 52, w - 24, 44)];
    search.placeholder = @"搜索曲名 / 编号 / 别名";
    search.searchBarStyle = UISearchBarStyleMinimal;
    search.delegate = self;
    search.autocorrectionType = UITextAutocorrectionTypeNo;
    search.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [card addSubview:search];
    self.search = search;

    CGFloat top = 98;
    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, top, w, h - top)
                                                      style:UITableViewStylePlain];
    table.backgroundColor = [UIColor clearColor];
    table.separatorInset = UIEdgeInsetsMake(0, 68, 0, 0);
    table.rowHeight = 58;
    table.dataSource = self;
    table.delegate = self;
    table.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [card addSubview:table];
    self.table = table;

    UILabel *empty = [[UILabel alloc] initWithFrame:CGRectMake(0, top + 60, w, 24)];
    empty.text = self.all.count ? @"没有匹配的曲目" : @"还没有收藏的曲目";
    empty.font = [UIFont systemFontOfSize:14];
    empty.textColor = [UIColor tertiaryLabelColor];
    empty.textAlignment = NSTextAlignmentCenter;
    empty.hidden = self.all.count > 0;
    [card addSubview:empty];
    self.empty = empty;
}

- (void)close
{
    __weak __typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.15 animations:^{ weakSelf.alpha = 0; } completion:^(BOOL done) {
        [weakSelf removeFromSuperview];
    }];
}

#pragma mark - 搜索

- (void)searchBar:(UISearchBar *)bar textDidChange:(NSString *)text
{
    NSString *q = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!q.length) {
        self.songs = self.all;
    } else {
        NSArray *hits = [ADXChartDb search:q limit:300];
        NSMutableArray *out = [NSMutableArray array];
        for (NSArray *s in self.all) {
            if ([hits containsObject:s]) [out addObject:s];
        }
        self.songs = out;
    }

    self.empty.hidden = (self.songs.count > 0);
    [self.table reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)bar
{
    [bar resignFirstResponder];
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
    if (style != UITableViewCellEditingStyleDelete) return;

    NSArray *s = self.songs[indexPath.row];
    [ADXChartFav toggle:[s[0] intValue]];

    NSMutableArray *list = [NSMutableArray arrayWithArray:self.songs];
    [list removeObjectAtIndex:indexPath.row];
    self.songs = list;

    NSMutableArray *all = [NSMutableArray arrayWithArray:self.all];
    if ([all containsObject:s]) [all removeObject:s];
    self.all = all;

    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    self.empty.hidden = (self.songs.count > 0);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *s = self.songs[indexPath.row];
    int sid = [s[0] intValue];
    void (^open)(int) = self.openBlock;
    [self close];
    if (open) open(sid);
}

@end
