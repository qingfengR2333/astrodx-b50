// Tweak.x — AstroDX B50 悬浮窗（注入后用，无 hook，纯挂一个浮窗）
#import <UIKit/UIKit.h>
#import "B50Core.h"
#import "ImportPanel.h"
#import "B50Image.h"
#import "SettingsPanel.h"

#pragma mark - 颜色

static UIColor *ADXDiffColor(int d)
{
    switch (d) {
        case 2: return [UIColor colorWithRed:0.23 green:0.55 blue:0.28 alpha:1.0];  // BASIC 绿
        case 3: return [UIColor colorWithRed:0.81 green:0.60 blue:0.15 alpha:1.0];  // ADVANCED 黄
        case 4: return [UIColor colorWithRed:0.78 green:0.26 blue:0.27 alpha:1.0];  // EXPERT 红
        case 5: return [UIColor colorWithRed:0.45 green:0.29 blue:0.70 alpha:1.0];  // MASTER 紫
        case 6: return [UIColor colorWithWhite:0.80 alpha:1.0];                    // RE:MASTER 白
        default: return [UIColor systemGrayColor];
    }
}

#pragma mark - B50 面板

@interface ADXB50Panel : UITableViewController
@property (nonatomic, strong) ADXB50Result *result;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, copy) NSString *errorText;
@end

@implementation ADXB50Panel

- (instancetype)init
{
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) self.title = @"B50成绩图";
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIBarButtonItem *reloadItem =
        [[UIBarButtonItem alloc] initWithTitle:@"重新读取" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(reloadData)];
    UIBarButtonItem *exportItem =
        [[UIBarButtonItem alloc] initWithTitle:@"导出 b50 成绩图" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(exportImage)];
    // 数组第一个在最右边
    self.navigationItem.rightBarButtonItems = @[exportItem, reloadItem];
    [self reloadData];
}

- (void)exportImage
{
    if (!self.result) return;

    NSString *oldTitle = self.title;
    self.title = @"B50成绩图 · 生成中…";
    for (UIBarButtonItem *b in self.navigationItem.rightBarButtonItems) b.enabled = NO;

    NSString *docs = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *png = [docs stringByAppendingPathComponent:@"astrodx_b50.png"];

    __weak __typeof(self) weakSelf = self;
    [ADXImage render:self.result
            coverDir:[docs stringByAppendingPathComponent:@"covers"]
              toPath:png
          completion:^(UIImage *image, NSError *error) {
        __typeof(weakSelf) me = weakSelf;
        if (!me) return;
        me.title = oldTitle;
        for (UIBarButtonItem *b in me.navigationItem.rightBarButtonItems) b.enabled = YES;

        if (!image) {
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"导出失败"
                                                                      message:error.localizedDescription
                                                               preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [me presentViewController:a animated:YES completion:nil];
            return;
        }

        UIActivityViewController *av =
            [[UIActivityViewController alloc] initWithActivityItems:@[image] applicationActivities:nil];
        av.popoverPresentationController.sourceView = me.view;
        av.popoverPresentationController.sourceRect =
            CGRectMake(CGRectGetMidX(me.view.bounds), 44, 1, 1);
        [me presentViewController:av animated:YES completion:nil];
    }];
}

- (void)reloadData
{
    self.loading = YES;
    self.errorText = nil;
    self.result = nil;
    [self.tableView reloadData];
    self.title = @"B50成绩图 · 读取中…";

    NSString *docs = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *cachePath = [docs stringByAppendingPathComponent:@"cache"];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *err = nil;
        NSDictionary *cache = [ADXB50 readCacheAt:cachePath error:&err];
        NSDictionary *db = nil;
        ADXB50Result *res = nil;
        if (!err) db = [ADXB50 songDbInDir:docs error:&err];
        if (!err) res = [ADXB50 computeWithCache:cache db:db];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.loading = NO;
            if (err) {
                self.errorText = err.localizedDescription;
                self.title = @"B50成绩图 · 失败";
            } else {
                self.result = res;
                self.title = [NSString stringWithFormat:@"B50成绩图 · %d", res.total];
            }
            [self.tableView reloadData];
        });
    });
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.result ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (!self.result) return 1;
    return section == 0 ? self.result.oldList.count : self.result.recentList.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (!self.result) return nil;
    if (section == 0)
        return [NSString stringWithFormat:@"旧曲 BEST 35 · 合计 %d", self.result.oldSum];
    return [NSString stringWithFormat:@"新曲 BEST 15 · 合计 %d", self.result.newSum];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (!self.result || section != 1) return nil;
    return [NSString stringWithFormat:@"当前版本 %d · 未识别 %d 首（自制谱/宴会场不参与）",
            self.result.current, self.result.unmatched];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];

    if (!self.result) {
        cell.textLabel.text = self.loading ? @"正在读取 cache…" : @"出错了";
        cell.detailTextLabel.text = self.loading ? @"" : self.errorText;
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        cell.detailTextLabel.numberOfLines = 0;
        return cell;
    }

    NSArray *list = indexPath.section == 0 ? self.result.oldList : self.result.recentList;
    ADXEntry *e = list[indexPath.row];

    cell.textLabel.text = [NSString stringWithFormat:@"%d.  %@", e.rank, e.title];
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.minimumScaleFactor = 0.7;

    cell.detailTextLabel.text = [NSString stringWithFormat:@"定数 %.1f · %@ · %@ · RA %d",
                                 e.ds, e.level, [NSString stringWithFormat:@"%.4f%%", e.rate], e.rating];
    cell.detailTextLabel.textColor = ADXDiffColor(e.diffId);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)shareFile:(NSString *)path
{
    NSURL *url = [NSURL fileURLWithPath:path];
    UIActivityViewController *av =
        [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    av.popoverPresentationController.sourceView = self.view;
    av.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), 44, 1, 1);
    [self presentViewController:av animated:YES completion:nil];
}

- (void)exportScoresCsv
{
    NSString *docs = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSError *err = nil;
    NSDictionary *cache = [ADXB50 readCacheAt:[docs stringByAppendingPathComponent:@"cache"] error:&err];
    if (!cache) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"导出失败"
                                                                  message:err.localizedDescription
                                                           preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    NSString *csv = [ADXB50 scoresCsv:cache playedOnly:YES];
    NSString *path = [docs stringByAppendingPathComponent:@"astrodx_scores.csv"];
    [csv writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self shareFile:path];
}

- (void)exportB50Csv
{
    if (!self.result) return;
    NSString *docs = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *path = [docs stringByAppendingPathComponent:@"astrodx_b50.csv"];
    [[ADXB50 b50Csv:self.result] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self shareFile:path];
}

@end

#pragma mark - 浮窗

@interface ADXRuntime : NSObject
@end

@implementation ADXRuntime

static UIWindow *gWindow;
static UIWindow *gPanelWindow;
static UIView *gBall;
static UILabel *gBallLabel;
static UIGestureRecognizer *gTapOnce;
static UIGestureRecognizer *gTapTwice;
static UIGestureRecognizer *gLongPress;
static CGSize gScreenSize;
static UINavigationController *gB50Nav;

+ (UIWindowScene *)activeScene
{
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] &&
            scene.activationState == UISceneActivationStateForegroundActive)
            return (UIWindowScene *)scene;
    }
    return nil;
}

+ (UIFont *)fontForBall:(CGFloat)side text:(NSString *)text
{
    for (CGFloat f = side * 0.42; f > 6; f -= 1) {
        UIFont *font = [UIFont boldSystemFontOfSize:f];
        CGSize sz = [text sizeWithAttributes:@{NSFontAttributeName: font}];
        if (sz.width <= side * 0.80 && sz.height <= side * 0.60) return font;
    }
    return [UIFont boldSystemFontOfSize:8];
}

+ (void)rebuildB50Items
{
    if (!gB50Nav) return;
    UIViewController *vc = gB50Nav.topViewController;

    NSMutableArray *items = [NSMutableArray array];
    [items addObject:[[UIBarButtonItem alloc] initWithTitle:@"关闭"
                                                      style:UIBarButtonItemStylePlain
                                                     target:self
                                                     action:@selector(closePanel)]];
    if ([ADXSettings showScoresButton])
        [items addObject:[[UIBarButtonItem alloc] initWithTitle:@"导出分表"
                                                          style:UIBarButtonItemStylePlain
                                                         target:vc
                                                         action:@selector(exportScoresCsv)]];
    if ([ADXSettings showB50Button])
        [items addObject:[[UIBarButtonItem alloc] initWithTitle:@"导出b50表"
                                                          style:UIBarButtonItemStylePlain
                                                         target:vc
                                                         action:@selector(exportB50Csv)]];
    vc.navigationItem.leftBarButtonItems = items;
}

+ (void)applySettings
{
    if (!gWindow || !gBall) return;

    CGFloat side = [ADXSettings size];
    CGRect f = gWindow.frame;
    CGPoint center = CGPointMake(CGRectGetMidX(f), CGRectGetMidY(f));
    f.size = CGSizeMake(side, side);
    f.origin = CGPointMake(center.x - side / 2, center.y - side / 2);
    f.origin.x = MAX(0, MIN(f.origin.x, gScreenSize.width - side));
    f.origin.y = MAX(0, MIN(f.origin.y, gScreenSize.height - side));
    gWindow.frame = f;

    gBall.frame = CGRectMake(0, 0, side, side);
    gBall.layer.cornerRadius = side / 2;
    gBall.backgroundColor = [[ADXSettings color] colorWithAlphaComponent:[ADXSettings alpha]];

    gBallLabel.frame = gBall.bounds;
    gBallLabel.text = [ADXSettings text];
    gBallLabel.font = [self fontForBall:side text:gBallLabel.text];
    gBallLabel.textColor = [UIColor colorWithWhite:1 alpha:[ADXSettings textAlpha]];

    [self rebuildB50Items];

    NSInteger t = [ADXSettings trigger];
    gTapOnce.enabled = (t == 0);
    gTapTwice.enabled = (t == 1);
    gLongPress.enabled = (t == 2);
}

+ (void)install
{
    if (gWindow) return;

    UIWindowScene *scene = [self activeScene];
    CGSize screen = scene ? scene.coordinateSpace.bounds.size : [UIScreen mainScreen].bounds.size;
    gScreenSize = screen;

    CGFloat side = 56;
    CGRect frame = CGRectMake(screen.width - side - 12, screen.height * 0.35, side, side);

    if (scene) {
        gWindow = [[UIWindow alloc] initWithWindowScene:scene];
        gWindow.frame = frame;
    } else {
        gWindow = [[UIWindow alloc] initWithFrame:frame];
    }
    gWindow.windowLevel = UIWindowLevelAlert + 1;
    gWindow.backgroundColor = [UIColor clearColor];
    gWindow.rootViewController = [UIViewController new];
    gWindow.rootViewController.view.backgroundColor = [UIColor clearColor];
    gWindow.hidden = NO;

    gBall = [[UIView alloc] initWithFrame:CGRectMake(0, 0, side, side)];
    gBall.layer.masksToBounds = NO;
    gBall.layer.shadowColor = [UIColor blackColor].CGColor;
    gBall.layer.shadowOpacity = 0.25;
    gBall.layer.shadowRadius = 6;
    gBall.layer.shadowOffset = CGSizeMake(0, 2);
    gBall.userInteractionEnabled = YES;

    gBallLabel = [[UILabel alloc] initWithFrame:gBall.bounds];
    gBallLabel.textColor = [UIColor whiteColor];
    gBallLabel.textAlignment = NSTextAlignmentCenter;
    gBallLabel.userInteractionEnabled = NO;
    [gBall addSubview:gBallLabel];

    UITapGestureRecognizer *once =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openPanel)];
    once.numberOfTapsRequired = 1;
    gTapOnce = once;

    UITapGestureRecognizer *twice =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openPanel)];
    twice.numberOfTapsRequired = 2;
    gTapTwice = twice;

    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];
    lp.minimumPressDuration = 0.6;
    gLongPress = lp;

    [gBall addGestureRecognizer:gTapOnce];
    [gBall addGestureRecognizer:gTapTwice];
    [gBall addGestureRecognizer:gLongPress];
    [gBall addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)]];

    [gWindow.rootViewController.view addSubview:gBall];

    [self applySettings];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applySettings)
                                                 name:ADXSettingsChangedNotification
                                               object:nil];
}

+ (void)onLongPress:(UILongPressGestureRecognizer *)g
{
    if (g.state == UIGestureRecognizerStateBegan) [self openPanel];
}

+ (void)pan:(UIPanGestureRecognizer *)g
{
    CGPoint t = [g translationInView:nil];
    CGRect f = gWindow.frame;
    CGFloat maxX = gScreenSize.width - f.size.width;
    CGFloat maxY = gScreenSize.height - f.size.height;
    f.origin.x = MAX(0, MIN(f.origin.x + t.x, maxX));
    f.origin.y = MAX(0, MIN(f.origin.y + t.y, maxY));
    gWindow.frame = f;
    [g setTranslation:CGPointZero inView:nil];
}

+ (void)openPanel
{
    if (gPanelWindow) return;

    CGSize screen = gScreenSize;
    CGFloat w = MIN(660, screen.width - 80);
    CGFloat h = MIN(780, screen.height - 80);
    CGRect frame = CGRectMake((screen.width - w) / 2, (screen.height - h) / 2, w, h);

    UIWindowScene *scene = [self activeScene];
    if (scene) {
        gPanelWindow = [[UIWindow alloc] initWithWindowScene:scene];
        gPanelWindow.frame = frame;
    } else {
        gPanelWindow = [[UIWindow alloc] initWithFrame:frame];
    }
    gPanelWindow.windowLevel = UIWindowLevelAlert + 2;
    gPanelWindow.backgroundColor = [UIColor systemBackgroundColor];
    gPanelWindow.layer.cornerRadius = 16;
    gPanelWindow.layer.masksToBounds = YES;

    ADXB50Panel *b50 = [ADXB50Panel new];
    UINavigationController *navB50 = [[UINavigationController alloc] initWithRootViewController:b50];
    navB50.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"B50成绩图"
                                                      image:[UIImage systemImageNamed:@"chart.bar.fill"]
                                                        tag:0];

    gB50Nav = navB50;
    [self rebuildB50Items];

    ADXImportPanel *imp = [ADXImportPanel new];
    UINavigationController *navImp = [[UINavigationController alloc] initWithRootViewController:imp];
    navImp.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"导入"
                                                      image:[UIImage systemImageNamed:@"square.and.arrow.down"]
                                                        tag:1];
    imp.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(closePanel)];

    ADXSettingsPanel *set = [ADXSettingsPanel new];
    UINavigationController *navSet = [[UINavigationController alloc] initWithRootViewController:set];
    navSet.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"设置"
                                                      image:[UIImage systemImageNamed:@"gearshape.fill"]
                                                        tag:2];
    set.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(closePanel)];

    UITabBarController *tabs = [UITabBarController new];
    tabs.viewControllers = @[navB50, navImp, navSet];
    gPanelWindow.rootViewController = tabs;
    gPanelWindow.hidden = NO;
}

+ (void)closePanel
{
    gPanelWindow.hidden = YES;
    gPanelWindow = nil;
    gB50Nav = nil;
}

@end

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [ADXRuntime install];
    });
}
