// Tweak.x — AstroDX B50 悬浮窗（注入后用，无 hook，纯挂一个浮窗）
#import <UIKit/UIKit.h>
#import "B50Core.h"
#import "ImportPanel.h"
#import "B50Image.h"
#import "SettingsPanel.h"
#import "ResourcePanel.h"
#import "AboutPanel.h"
#import "ChartPanel.h"
#import "ChartDb.h"
#import <math.h>

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

@interface ADXB50Panel : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) ADXB50Result *result;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, copy) NSString *errorText;
@property (nonatomic, strong) UISegmentedControl *seg;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) ADXChartPanel *chart;
@end

@implementation ADXB50Panel

- (instancetype)init
{
    self = [super init];
    if (self) self.title = @"B50列表";
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    self.seg = [[UISegmentedControl alloc] initWithItems:@[@"B50成绩", @"谱面查询"]];
    self.seg.selectedSegmentIndex = 0;
    [self.seg addTarget:self action:@selector(segmentChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.seg];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.backgroundColor = [UIColor clearColor];
    self.table.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.table];

    self.chart = [[ADXChartPanel alloc] initWithFrame:CGRectZero];
    self.chart.coverDir = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]
                           stringByAppendingPathComponent:@"covers"];
    self.chart.hidden = YES;
    [self.view addSubview:self.chart];

    // 导航栏按钮由 ADXRuntime 的 rebuildB50Items 统一生成（受设置里的开关控制）
    [self reloadData];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGFloat W = self.view.bounds.size.width;
    CGFloat top = self.view.safeAreaInsets.top + 6;

    self.seg.frame = CGRectMake(16, top, W - 32, 32);

    CGFloat y = top + 32 + 6;
    CGFloat h = self.view.bounds.size.height - y - self.view.safeAreaInsets.bottom;
    CGRect area = CGRectMake(0, y, W, MAX(0, h));
    self.table.frame = area;
    self.chart.frame = area;
}

- (void)segmentChanged
{
    BOOL chart = (self.seg.selectedSegmentIndex == 1);
    self.table.hidden = chart;
    self.chart.hidden = !chart;
    if (!chart) [self.table reloadData];
}

- (void)exportImage
{
    if (!self.result) return;

    NSString *oldTitle = self.title;
    self.title = @"B50列表 · 生成中…";
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
    [self.table reloadData];
    self.title = @"B50列表 · 读取中…";

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
                self.title = @"B50列表 · 失败";
            } else {
                self.result = res;
                self.title = [NSString stringWithFormat:@"B50列表 · %d", res.total];
            }
            [self.table reloadData];
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

    NSArray *list = (section == 0) ? self.result.oldList : self.result.recentList;
    int sum = (section == 0) ? self.result.oldSum : self.result.newSum;
    // 折算成“满 50 首”的等效 rating：合计 / 首数 * 50
    int normalized = list.count ? (int)lround(sum / (double)list.count * 50.0) : 0;
    NSString *name = (section == 0) ? @"旧曲 BEST 35" : @"新曲 BEST 15";
    return [NSString stringWithFormat:@"%@ · 合计 %d · 计算后 %d", name, sum, normalized];
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
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
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
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!self.result) return;

    NSArray *list = indexPath.section == 0 ? self.result.oldList : self.result.recentList;
    ADXEntry *e = list[indexPath.row];

    // 自制谱 / 宴会场不在曲库里，点不进详情
    if (![ADXChartDb songById:e.songId]) return;

    // 切到「谱面查询」并直接展示这首歌的详情
    self.seg.selectedSegmentIndex = 1;
    [self segmentChanged];
    [self.chart showSongById:e.songId];
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

/// 屏幕旋转后重新按当前场景尺寸摆浮球 / 面板
+ (void)relayout
{
    UIWindowScene *scene = gWindow.windowScene ?: [self activeScene];
    CGSize s = scene ? scene.coordinateSpace.bounds.size : [UIScreen mainScreen].bounds.size;
    gScreenSize = s;

    if (gWindow) {
        gWindow.frame = CGRectMake(0, 0, s.width, s.height);
        gWindow.opaque = NO;
        gWindow.backgroundColor = [UIColor clearColor];
        gWindow.rootViewController.view.opaque = NO;
        gWindow.rootViewController.view.backgroundColor = [UIColor clearColor];
        [gWindow layoutIfNeeded];
        [self applySettings];          // 重新按新尺寸夹一次浮球位置
    }

    if (gPanelWindow) {
        CGFloat w = MIN(660, s.width - 80);
        CGFloat h = MIN(780, s.height - 80);
        gPanelWindow.frame = CGRectMake((s.width - w) / 2, (s.height - h) / 2, w, h);
        gPanelWindow.opaque = NO;
        gPanelWindow.backgroundColor = [UIColor clearColor];
        [gPanelWindow layoutIfNeeded];
    }
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

    NSMutableArray *right = [NSMutableArray array];
    if ([ADXSettings showImageButton])
        [right addObject:[[UIBarButtonItem alloc] initWithTitle:@"导出 b50 成绩图"
                                                          style:UIBarButtonItemStylePlain
                                                         target:vc
                                                         action:@selector(exportImage)]];
    [right addObject:[[UIBarButtonItem alloc] initWithTitle:@"重新读取"
                                                      style:UIBarButtonItemStylePlain
                                                     target:vc
                                                     action:@selector(reloadData)]];
    vc.navigationItem.rightBarButtonItems = right;
}

+ (void)applySettings
{
    if (!gWindow || !gBall) return;

    CGFloat side = [ADXSettings size];

    // 窗口始终铺满全屏，浮球是里面的一个子视图。
    // 之前是「窗口只有 56×56」，旋转时 UIKit 会按旧尺寸重建窗口，
    // 圆球外面那圈方形就被涂成黑底，于是出现四个黑方块。
    CGRect b = gWindow.bounds;
    if (b.size.width < 1 || b.size.height < 1) b = CGRectMake(0, 0, gScreenSize.width, gScreenSize.height);

    CGPoint c = gBall.center;
    if (c.x < 1 && c.y < 1) c = CGPointMake(b.size.width - side / 2 - 12, b.size.height * 0.35);
    c.x = MAX(side / 2, MIN(c.x, b.size.width - side / 2));
    c.y = MAX(side / 2, MIN(c.y, b.size.height - side / 2));

    gBall.bounds = CGRectMake(0, 0, side, side);
    gBall.center = c;
    gBall.opaque = NO;
    gBall.layer.cornerRadius = side / 2;
    gBall.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:gBall.bounds].CGPath;
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

    if (scene) {
        gWindow = [[UIWindow alloc] initWithWindowScene:scene];
    } else {
        gWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, screen.width, screen.height)];
    }
    gWindow.frame = CGRectMake(0, 0, screen.width, screen.height);   // 铺满全屏，浮球做成子视图
    gWindow.windowLevel = UIWindowLevelAlert + 1;
    gWindow.opaque = NO;
    gWindow.backgroundColor = [UIColor clearColor];
    gWindow.rootViewController = [UIViewController new];
    gWindow.rootViewController.view.opaque = NO;
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

    // 旋转 / 尺寸变化：重新摆浮球，并强制窗口保持透明（否则圆球四角会露黑底）
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    for (NSString *n in @[UIDeviceOrientationDidChangeNotification,
                          UIApplicationDidChangeStatusBarOrientationNotification,
                          UIWindowDidBecomeKeyNotification]) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(relayout)
                                                     name:n
                                                   object:nil];
    }
}

+ (void)onLongPress:(UILongPressGestureRecognizer *)g
{
    if (g.state == UIGestureRecognizerStateBegan) [self openPanel];
}

+ (void)pan:(UIPanGestureRecognizer *)g
{
    CGPoint t = [g translationInView:nil];
    CGRect b = gWindow.bounds;
    CGPoint c = gBall.center;
    CGFloat side = gBall.bounds.size.width;
    c.x = MAX(side / 2, MIN(c.x + t.x, b.size.width - side / 2));
    c.y = MAX(side / 2, MIN(c.y + t.y, b.size.height - side / 2));
    gBall.center = c;
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
    navB50.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"B50列表"
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

    ADXResourcePanel *res = [ADXResourcePanel new];
    UINavigationController *navRes = [[UINavigationController alloc] initWithRootViewController:res];
    navRes.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"资源管理"
                                                      image:[UIImage systemImageNamed:@"folder.fill"]
                                                        tag:2];
    res.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(closePanel)];

    ADXSettingsPanel *set = [ADXSettingsPanel new];
    UINavigationController *navSet = [[UINavigationController alloc] initWithRootViewController:set];
    navSet.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"设置"
                                                      image:[UIImage systemImageNamed:@"gearshape.fill"]
                                                        tag:3];
    set.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(closePanel)];

    ADXAboutPanel *about = [ADXAboutPanel new];
    UINavigationController *navAbout = [[UINavigationController alloc] initWithRootViewController:about];
    navAbout.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"关于"
                                                        image:[UIImage systemImageNamed:@"info.circle.fill"]
                                                          tag:4];
    about.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(closePanel)];

    UITabBarController *tabs = [UITabBarController new];
    tabs.viewControllers = @[navB50, navImp, navRes, navSet, navAbout];
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
