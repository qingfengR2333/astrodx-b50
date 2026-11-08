// Tweak.x — AstroDX B50 悬浮窗（注入后用，无 hook，纯挂一个浮窗）
#import <UIKit/UIKit.h>
#import "B50Core.h"
#import "ImportPanel.h"
#import "B50Image.h"

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
        [[UIBarButtonItem alloc] initWithTitle:@"导出图" style:UIBarButtonItemStyleDone
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

@end

#pragma mark - 浮窗

@interface ADXRuntime : NSObject
@end

@implementation ADXRuntime

static UIWindow *gWindow;
static UIWindow *gPanelWindow;
static UIView *gBall;
static CGSize gScreenSize;

+ (UIWindowScene *)activeScene
{
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] &&
            scene.activationState == UISceneActivationStateForegroundActive)
            return (UIWindowScene *)scene;
    }
    return nil;
}

/// 找到游戏自己的顶层控制器（用来弹面板，别用我们那个小窗口）
+ (UIViewController *)appTopViewController
{
    UIWindow *target = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (w == gWindow) continue;
            if (w.isKeyWindow) { target = w; break; }
        }
        if (target) break;
    }
    UIViewController *vc = target.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

+ (void)install
{
    if (gWindow) return;

    UIWindowScene *scene = [self activeScene];
    CGSize screen = scene ? scene.coordinateSpace.bounds.size : [UIScreen mainScreen].bounds.size;
    gScreenSize = screen;

    const CGFloat side = 56;
    CGRect frame = CGRectMake(screen.width - side - 12, screen.height * 0.35, side, side);

    // 关键：窗口只有 56×56，只盖住球本身，屏幕其余部分完全不受影响
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

    UIView *ball = [[UIView alloc] initWithFrame:CGRectMake(0, 0, side, side)];
    ball.backgroundColor = [UIColor colorWithRed:0.26 green:0.52 blue:0.97 alpha:0.92];
    ball.layer.cornerRadius = side / 2;
    ball.layer.masksToBounds = NO;
    ball.layer.shadowColor = [UIColor blackColor].CGColor;
    ball.layer.shadowOpacity = 0.25;
    ball.layer.shadowRadius = 6;
    ball.layer.shadowOffset = CGSizeMake(0, 2);
    ball.userInteractionEnabled = YES;

    UILabel *ballLabel = [[UILabel alloc] initWithFrame:ball.bounds];
    ballLabel.text = @"ADX";
    ballLabel.textColor = [UIColor whiteColor];
    ballLabel.font = [UIFont boldSystemFontOfSize:15];
    ballLabel.textAlignment = NSTextAlignmentCenter;
    ballLabel.userInteractionEnabled = NO;
    [ball addSubview:ballLabel];

    // 双击才打开，避免游玩时误触
    UITapGestureRecognizer *doubleTap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openPanel)];
    doubleTap.numberOfTapsRequired = 2;
    [ball addGestureRecognizer:doubleTap];
    [ball addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)]];

    gBall = ball;
    [gWindow.rootViewController.view addSubview:ball];
}

/// 拖动的是整个窗口（不是球），所以球的点击区域始终跟着走
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

/// 面板放在自己的窗口里（只有面板那么大），不走模态弹出，
/// 避免 Unity 的视图层级把 form sheet 挤变形
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
    navB50.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"B50"
                                                      image:[UIImage systemImageNamed:@"chart.bar.fill"]
                                                        tag:0];
    b50.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStyleDone
                                        target:self action:@selector(closePanel)];

    ADXImportPanel *imp = [ADXImportPanel new];
    UINavigationController *navImp = [[UINavigationController alloc] initWithRootViewController:imp];
    navImp.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"导入"
                                                      image:[UIImage systemImageNamed:@"square.and.arrow.down"]
                                                        tag:1];
    imp.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStyleDone
                                        target:self action:@selector(closePanel)];

    UITabBarController *tabs = [UITabBarController new];
    tabs.viewControllers = @[navB50, navImp];
    gPanelWindow.rootViewController = tabs;
    gPanelWindow.hidden = NO;
}

+ (void)closePanel
{
    gPanelWindow.hidden = YES;
    gPanelWindow = nil;
}

@end

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [ADXRuntime install];
    });
}
