// ChartFav.m — 收藏夹存储 + 收藏夹弹窗
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

#pragma mark - 弹窗

@interface ADXChartFavSheet () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIView *dim;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIView *content;
@property (nonatomic, strong) UITableView *table;
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
    // 先把收藏 id 解析成曲目
    NSMutableArray *list = [NSMutableArray array];
    for (NSNumber *n in [ADXChartFav ids]) {
        NSArray *s = [ADXChartDb songById:[n intValue]];
        if (s) [list addObject:s];
    }
    self.songs = list;

    CGFloat w = MIN(520, self.bounds.size.width - 64);
    CGFloat h = MIN(560, self.bounds.size.height - 140);

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake((self.bounds.size.width - w) / 2,
                                                           (self.bounds.size.height - h) / 2, w, h)];
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 16;
    card.layer.masksToBounds = YES;
    card.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self addSubview:card];
    self.card = card;

    UIView *content = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 52)];
    [card addSubview:content];
    self.content = content;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, w - 80, 52)];
    title.text = @"收藏夹";
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    [content addSubview:title];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(w - 72, 0, 56, 52);
    [close setTitle:@"关闭" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:15];
    [close addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:close];

    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 52, w, 0.5)];
    line.backgroundColor = [UIColor separatorColor];
    [content addSubview:line];

    CGFloat top = 52;
    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, top, w, h - top)
                                                      style:UITableViewStylePlain];
    table.backgroundColor = [UIColor clearColor];
    table.separatorInset = UIEdgeInsetsMake(0, 62, 0, 0);
    table.rowHeight = 60;
    table.dataSource = self;
    table.delegate = self;
    [card addSubview:table];
    self.table = table;

    if (!self.songs.count) {
        UILabel *none = [[UILabel alloc] initWithFrame:CGRectMake(0, top + 40, w, 24)];
        none.text = @"还没有收藏的曲目";
        none.font = [UIFont systemFontOfSize:14];
        none.textColor = [UIColor tertiaryLabelColor];
        none.textAlignment = NSTextAlignmentCenter;
        [card addSubview:none];
    }
}

- (void)close
{
    __weak __typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.15 animations:^{ weakSelf.alpha = 0; } completion:^(BOOL done) {
        [weakSelf removeFromSuperview];
    }];
}

#pragma mark - 表格

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.songs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"fav"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"fav"];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        cell.imageView.layer.cornerRadius = 6;
        cell.imageView.layer.masksToBounds = YES;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    NSArray *s = self.songs[indexPath.row];
    cell.textLabel.text = s[1];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", s[2], [ADXChartDb numberText:s]];

    int sid = [s[0] intValue];
    NSString *url = [ADXChartDb coverURL:s];
    cell.imageView.image = nil;
    cell.imageView.backgroundColor = [UIColor secondarySystemBackgroundColor];

    __weak UITableViewCell *weakCell = cell;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *img = url.length ? [ADXImage coverImageFor:sid url:url dir:FavCoverDir()]
                                  : [ADXImage coverImageFor:sid dir:FavCoverDir()];
        if (!img) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakCell.textLabel.text.length) {
                weakCell.imageView.image = img;
                [weakCell setNeedsLayout];
            }
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

    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
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
