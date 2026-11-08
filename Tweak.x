// Tweak.x — AstroDX B50 悬浮窗（注入后用，无 hook，纯挂一个浮窗）
#import <UIKit/UIKit.h>
#import "B50Core.h"

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
- (void)dismissSelf;
@end

@implementation ADXB50Panel

- (instancetype)init
{
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) self.title = @"B50 v2";
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"重新读取" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(reloadData)];
    [self reloadData];
}

- (void)reloadData
{
    self.loading = YES;
    self.errorText = nil;
    self.result = nil;
    [self.tableView reloadData];
    self.title = @"B50 v2 · 读取中…";

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
                self.title = @"B50 v2 · 失败";
            } else {
                self.result = res;
                self.title = [NSString stringWithFormat:@"B50 v2 · %d", res.total];
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

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

@end

#pragma mark - 浮窗

@interface ADXRuntime : NSObject
@end

@implementation ADXRuntime

static UIWindow *gWindow;
static UIButton *gButton;
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

    gButton = [UIButton buttonWithType:UIButtonTypeCustom];
    gButton.frame = CGRectMake(0, 0, side, side);
    gButton.layer.cornerRadius = side / 2;
    gButton.layer.masksToBounds = NO;
    gButton.backgroundColor = [UIColor colorWithRed:0.26 green:0.52 blue:0.97 alpha:0.92];
    gButton.layer.shadowColor = [UIColor blackColor].CGColor;
    gButton.layer.shadowOpacity = 0.25;
    gButton.layer.shadowRadius = 6;
    gButton.layer.shadowOffset = CGSizeMake(0, 2);
    [gButton setTitle:@"B50" forState:UIControlStateNormal];
    gButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [gButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [gButton addTarget:self action:@selector(openPanel) forControlEvents:UIControlEventTouchUpInside];
    [gButton addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)]];
    [gWindow.rootViewController.view addSubview:gButton];
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

+ (void)openPanel
{
    UIViewController *host = [self appTopViewController];
    if (!host) host = gWindow.rootViewController;
    if (!host || host.presentedViewController) return;

    ADXB50Panel *panel = [ADXB50Panel new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:panel];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    nav.preferredContentSize = CGSizeMake(620, 780);
    panel.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStyleDone
                                        target:panel action:@selector(dismissSelf)];
    [host presentViewController:nav animated:YES completion:nil];
}

@end

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [ADXRuntime install];
    });
}
