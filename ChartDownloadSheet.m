// ChartDownloadSheet.m — 谱面下载：adxdls 的线路 + 直链文件，下载完直接落进 levels
#import "ChartDownloadSheet.h"
#import "ChartDb.h"
#import "Zip.h"

static UIColor *DRGB(CGFloat r, CGFloat g, CGFloat b)
{
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}

/// 站点右上角「设置」里的线路，顺序即兜底顺序
static NSArray *AdxLines(void)
{
    return @[@[@"R2", @"astrodx-charts.saop.cc", @"推荐", @"Cloudflare R2 主线路，默认选择"],
             @[@"Alice", @"astrodx-charts-alice.saop.cc", @"备用", @"Alice 下载分流"],
             @[@"G510", @"astrodx-charts-g510.saop.cc", @"备用", @"G510 下载分流"],
             @[@"WMC", @"astrodx-charts-wmc.saop.cc", @"备用", @"WMC 下载分流"],
             @[@"Tsumugi", @"astrodx-charts-tsumugi.saop.cc", @"备用", @"Tsumugi 下载分流"]];
}

/// 日服版本表（adxdls 的 versionid 就是下标）
static NSArray *AdxJpVersions(void)
{
    return @[@"maimai", @"maimai PLUS", @"maimai GreeN", @"maimai GreeN PLUS",
             @"maimai ORANGE", @"maimai ORANGE PLUS", @"maimai PiNK", @"maimai PiNK PLUS",
             @"maimai MURASAKi", @"maimai MURASAKi PLUS", @"maimai MiLK", @"maimai MiLK PLUS",
             @"maimai FiNALE", @"maimai DX", @"maimai DX PLUS", @"maimai DX Splash",
             @"maimai DX Splash PLUS", @"maimai DX UNiVERSE", @"maimai DX UNiVERSE PLUS",
             @"maimai DX FESTiVAL", @"maimai DX FESTiVAL PLUS", @"maimai DX BUDDiES",
             @"maimai DX BUDDiES PLUS", @"maimai DX PRiSM", @"maimai DX PRiSM PLUS",
             @"maimai DX CiRCLE", @"maimai DX CiRCLE PLUS", @"maimai DX MAGiCAL"];
}

/// 延迟 → 圆点颜色：绿 正常 / 黄 一般 / 红 不可用
static UIColor *LatencyColor(NSInteger ms)
{
    if (ms < 0) return DRGB(255, 69, 58);        // 探测中或不可用
    if (ms < 600) return DRGB(52, 199, 89);
    if (ms < 1500) return DRGB(255, 204, 0);
    return DRGB(255, 69, 58);
}

@interface ADXChartDownloadSheet ()

@property (nonatomic, strong) UIView *dim;
@property (nonatomic, strong) UIView *card;

@property (nonatomic, strong) UIButton *goButton;
@property (nonatomic, strong) UIButton *optButton;
@property (nonatomic, strong) UILabel *sizeLabel;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIView *bgaRow;
@property (nonatomic, strong) UISwitch *bgaSwitch;
@property (nonatomic, strong) UIProgressView *bar;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, strong) UIButton *exportButton;

@property (nonatomic, strong) NSArray *song;
@property (nonatomic, assign) BOOL isDx;
@property (nonatomic, assign) BOOL panelOpen;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) BOOL cancelled;
@property (nonatomic, strong) NSURLSessionDataTask *task;
@property (nonatomic, assign) NSInteger line;
@property (nonatomic, copy) NSString *lastPath;          // 上次成功导入的文件夹，导出直接复用它
@property (nonatomic, copy) NSString *importedPath;      // 已导入 levels 的目录
@property (nonatomic, copy) NSString *tmpRoot;           // 本次下载的临时根目录（关闭时删除）
@property (nonatomic, copy) NSString *tmpFolder;         // 临时目录里的谱面文件夹（还没导入）
@property (nonatomic, copy) NSString *pendingZip;        // 已打好、等待分享/导入的 zip
@property (nonatomic, strong) NSMutableArray *dots;      // 每个线路的小圆点
@property (nonatomic, strong) NSMutableArray *checks;    // 每个线路的 ✓
@property (nonatomic, strong) NSMutableArray *latency;   // NSNumber，-1 未知 / -2 不可用
@property (nonatomic, strong) NSMutableArray *latencyLabels;

+ (long long)lengthOf:(NSString *)url;
+ (NSInteger)probeLatency:(NSString *)url;
+ (NSString *)uniquePath:(NSString *)path;

@end

@implementation ADXChartDownloadSheet

#pragma mark - 弹出

+ (void)presentSong:(NSArray *)song dx:(BOOL)dx inView:(UIView *)host
{
    if (!host || !song) return;

    ADXChartDownloadSheet *sheet = [[ADXChartDownloadSheet alloc] initWithFrame:host.bounds];
    sheet.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    sheet.backgroundColor = [UIColor clearColor];
    sheet.song = song;
    sheet.isDx = dx;
    sheet.line = 0;
    sheet.dots = [NSMutableArray array];
    sheet.checks = [NSMutableArray array];
    sheet.latencyLabels = [NSMutableArray array];
    sheet.latency = [NSMutableArray array];

    for (NSUInteger i = 0; i < AdxLines().count; i++) [sheet.latency addObject:@(-1)];

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

    [sheet measureSize];
    [sheet measureLatency];
}

- (void)close
{
    if (self.running) {          // 下载中要关：先中止再关
        self.cancelled = YES;
        [self.task cancel];
        self.running = NO;
    }

    [self cleanupTemp];

    __weak __typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.15 animations:^{ weakSelf.alpha = 0; } completion:^(BOOL done) {
        [weakSelf removeFromSuperview];
    }];
}

/// 关掉面板时清掉本次下载留下的临时文件（已导入 levels 的那份不动）
- (void)cleanupTemp
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if (self.tmpRoot.length) {
        [fm removeItemAtPath:self.tmpRoot error:nil];
        self.tmpRoot = nil;
    }
    self.tmpFolder = nil;
    if (self.pendingZip.length) {
        [fm removeItemAtPath:self.pendingZip error:nil];
        self.pendingZip = nil;
    }
}

#pragma mark - 界面

- (void)build
{
    CGFloat w = MIN(520, self.bounds.size.width - 56);

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake((self.bounds.size.width - w) / 2, 0, w, 380)];
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 16;
    card.layer.masksToBounds = YES;
    [self addSubview:card];
    self.card = card;

    CGFloat pad = 20;
    CGFloat inner = w - pad * 2;

    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(pad, 12, inner - 140, 32)];
    title.text = @"谱面下载";
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    [card addSubview:title];

    // 右上角：谱面导出（关闭按钮已去掉，点卡片外即可关闭）
    self.exportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.exportButton.frame = CGRectMake(w - pad - 84, 12, 80, 32);
    [self.exportButton setTitle:@"谱面导出" forState:UIControlStateNormal];
    self.exportButton.titleLabel.font = [UIFont systemFontOfSize:15];
    [self.exportButton addTarget:self action:@selector(exportTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.exportButton];

    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 52, w, 0.5)];
    line.backgroundColor = [UIColor separatorColor];
    [card addSubview:line];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(pad, 60, inner, 18)];
    sub.text = [NSString stringWithFormat:@"%@ · %@", self.song[1],
                [ADXChartDb versionText:self.song dx:self.isDx]];
    sub.font = [UIFont systemFontOfSize:12];
    sub.textColor = [UIColor secondaryLabelColor];
    sub.lineBreakMode = NSLineBreakByTruncatingTail;
    [card addSubview:sub];

    // 站内下载 .zip
    self.goButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.goButton.frame = CGRectMake(pad, 86, 168, 40);
    [self.goButton setTitle:@"⤓  站内下载 .zip" forState:UIControlStateNormal];
    self.goButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.goButton.backgroundColor = DRGB(110, 124, 240);
    [self.goButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.goButton.layer.cornerRadius = 9;
    [self.goButton addTarget:self action:@selector(startTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.goButton];

    // 下载选项
    self.optButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.optButton.frame = CGRectMake(pad + 178, 86, 118, 40);
    [self.optButton setTitle:@"下载选项 ⌄" forState:UIControlStateNormal];
    self.optButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.optButton.backgroundColor = [UIColor tertiarySystemFillColor];
    [self.optButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    self.optButton.layer.cornerRadius = 9;
    [self.optButton addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.optButton];

    self.sizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad + 306, 86, inner - 306, 40)];
    self.sizeLabel.text = @"正在计算…";
    self.sizeLabel.font = [UIFont systemFontOfSize:12];
    self.sizeLabel.textColor = [UIColor secondaryLabelColor];
    [card addSubview:self.sizeLabel];

    [self buildPanelIn:card width:inner x:pad];

    // 包含 BGA（默认关）
    UIView *bga = [[UIView alloc] initWithFrame:CGRectMake(pad, 0, inner, 46)];
    UILabel *bgaTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 2, inner - 60, 18)];
    bgaTitle.text = @"包含 BGA 视频";
    bgaTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [bga addSubview:bgaTitle];

    UILabel *bgaNote = [[UILabel alloc] initWithFrame:CGRectMake(0, 22, inner - 60, 16)];
    bgaNote.text = @"只影响背景动画，不影响谱面游玩。";
    bgaNote.font = [UIFont systemFontOfSize:11.5];
    bgaNote.textColor = [UIColor tertiaryLabelColor];
    [bga addSubview:bgaNote];

    self.bgaSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(inner - 51, 8, 51, 31)];
    self.bgaSwitch.on = NO;
    self.bgaSwitch.transform = CGAffineTransformMakeScale(0.82, 0.82);
    [bga addSubview:self.bgaSwitch];

    [card addSubview:bga];
    self.bgaRow = bga;

    self.bar = [[UIProgressView alloc] initWithFrame:CGRectMake(pad, 0, inner, 4)];
    self.bar.progress = 0;
    self.bar.hidden = YES;
    [card addSubview:self.bar];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, 0, inner, 20)];
    self.statusLabel.font = [UIFont systemFontOfSize:12];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.hidden = YES;
    [card addSubview:self.statusLabel];

    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startButton setTitle:@"开始下载" forState:UIControlStateNormal];
    self.startButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.startButton.backgroundColor = [UIColor systemBlueColor];
    [self.startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.startButton.layer.cornerRadius = 10;
    [self.startButton addTarget:self action:@selector(startTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.startButton];

    [self layoutCard];
}

- (void)buildPanelIn:(UIView *)card width:(CGFloat)inner x:(CGFloat)pad
{
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(pad, 0, inner, 0)];
    panel.clipsToBounds = YES;
    [card addSubview:panel];
    self.panel = panel;

    UILabel *head = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, inner, 20)];
    head.text = @"下载线路";
    head.font = [UIFont systemFontOfSize:11.5];
    head.textColor = [UIColor tertiaryLabelColor];
    [panel addSubview:head];

    NSArray *lines = AdxLines();
    CGFloat rowH = 54;
    CGFloat y = 22;

    for (NSUInteger i = 0; i < lines.count; i++) {
        NSArray *l = lines[i];

        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, y, inner, rowH)];
        row.backgroundColor = [UIColor clearColor];

        UIButton *tap = [UIButton buttonWithType:UIButtonTypeCustom];
        tap.frame = row.bounds;
        tap.tag = (NSInteger)i;
        [tap addTarget:self action:@selector(lineTapped:) forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:tap];

        UILabel *dot = [[UILabel alloc] initWithFrame:CGRectMake(2, 17, 8, 8)];
        dot.backgroundColor = LatencyColor(-1);
        dot.layer.cornerRadius = 4;
        dot.layer.masksToBounds = YES;
        [row addSubview:dot];
        [self.dots addObject:dot];

        UIFont *nf = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(18, 6, 120, 18)];
        name.text = l[0];
        name.font = nf;
        [row addSubview:name];

        CGFloat nameW = [l[0] sizeWithAttributes:@{NSFontAttributeName: nf}].width;
        UILabel *tag = [[UILabel alloc] initWithFrame:CGRectMake(18 + ceil(nameW) + 6, 8, 44, 15)];
        tag.text = l[2];
        tag.font = [UIFont systemFontOfSize:10];
        tag.textColor = [UIColor secondaryLabelColor];
        tag.textAlignment = NSTextAlignmentCenter;
        tag.backgroundColor = [UIColor tertiarySystemFillColor];
        tag.layer.cornerRadius = 4;
        tag.layer.masksToBounds = YES;
        [row addSubview:tag];

        UILabel *lat = [[UILabel alloc] initWithFrame:CGRectMake(inner - 96, 6, 74, 18)];
        lat.text = @"…";
        lat.font = [UIFont systemFontOfSize:12];
        lat.textColor = [UIColor secondaryLabelColor];
        lat.textAlignment = NSTextAlignmentRight;
        [row addSubview:lat];
        [self.latencyLabels addObject:lat];

        UILabel *check = [[UILabel alloc] initWithFrame:CGRectMake(inner - 22, 6, 20, 18)];
        check.text = @"✓";
        check.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        check.textColor = [UIColor systemBlueColor];
        check.textAlignment = NSTextAlignmentRight;
        check.hidden = (i != 0);
        [row addSubview:check];
        [self.checks addObject:check];

        UILabel *note = [[UILabel alloc] initWithFrame:CGRectMake(18, 28, inner - 18, 16)];
        note.text = l[3];
        note.font = [UIFont systemFontOfSize:11.5];
        note.textColor = [UIColor tertiaryLabelColor];
        [row addSubview:note];

        UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, rowH - 0.5, inner, 0.5)];
        sep.backgroundColor = [UIColor separatorColor];
        [row addSubview:sep];

        [panel addSubview:row];
        y += rowH;
    }

    UILabel *tail = [[UILabel alloc] initWithFrame:CGRectMake(0, y + 4, inner, 16)];
    tail.text = @"绿点延迟正常，黄点一般，红点不可用；下载失败会自动换线。";
    tail.font = [UIFont systemFontOfSize:11];
    tail.textColor = [UIColor tertiaryLabelColor];
    [panel addSubview:tail];

    panel.frame = CGRectMake(pad, 136, inner, 0);
}

- (void)layoutCard
{
    CGFloat w = self.card.bounds.size.width;
    CGFloat pad = 20;
    CGFloat inner = w - pad * 2;

    CGFloat rows = AdxLines().count * 54;
    CGFloat panelH = self.panelOpen ? (22 + rows + 24) : 0;
    self.panel.frame = CGRectMake(pad, 136, inner, panelH);

    CGFloat y = 136 + panelH + 2;
    self.bgaRow.frame = CGRectMake(pad, y, inner, 46);
    y += 46;

    if (!self.bar.hidden) {
        self.bar.frame = CGRectMake(pad, y + 4, inner, 4);
        self.statusLabel.frame = CGRectMake(pad, y + 10, inner, 20);
        y += 36;
    }

    if (!self.startButton.hidden) {
        self.startButton.frame = CGRectMake(pad, y + 8, inner, 44);
        y += 8 + 44;
    }
    y += 20;

    CGRect f = self.card.frame;
    f.size.height = y;
    f.origin.y = MAX(24, round((self.bounds.size.height - y) / 2));
    self.card.frame = f;
}

- (void)togglePanel
{
    self.panelOpen = !self.panelOpen;
    [self.optButton setTitle:(self.panelOpen ? @"下载选项 ⌃" : @"下载选项 ⌄") forState:UIControlStateNormal];

    [UIView animateWithDuration:0.2 animations:^{
        [self layoutCard];
        [self.card layoutIfNeeded];
    }];
}

- (void)lineTapped:(UIButton *)b
{
    self.line = b.tag;
    for (NSUInteger i = 0; i < self.checks.count; i++) {
        UILabel *c = self.checks[i];
        c.hidden = (i != (NSUInteger)self.line);
    }
}

#pragma mark - 探测：大小 + 延迟

- (int)shortId
{
    int base = [self.song[0] intValue];
    if ([ADXChartDb isJpOnly:self.song]) return base - 900000;
    return self.isDx ? [ADXChartDb displayId:self.song] : base;
}

- (int)versionId
{
    NSString *jp = [ADXChartDb jpVersionName:self.song dx:self.isDx];
    NSUInteger idx = [AdxJpVersions() indexOfObject:jp];
    if (idx == NSNotFound) return 27;
    return (int)idx;
}

- (NSString *)urlFor:(NSString *)name host:(NSString *)host
{
    return [NSString stringWithFormat:@"https://%@/%d/%d/%@", host, [self versionId], [self shortId], name];
}

- (void)measureSize
{
    NSString *host = AdxLines()[0][1];
    NSArray *probes = @[[self urlFor:@"track.mp3" host:host], [self urlFor:@"bg.png" host:host]];
    NSString *bgaHost = host;
    NSString *bgaURL = [self urlFor:@"pv.mp4" host:bgaHost];

    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        long long total = 0;
        for (NSString *u in probes) {
            long long n = [ADXChartDownloadSheet lengthOf:u];
            if (n > 0) total += n;
        }
        long long pv = [ADXChartDownloadSheet lengthOf:bgaURL];
        dispatch_async(dispatch_get_main_queue(), ^{
            __typeof(weakSelf) me = weakSelf;
            if (!me) return;
            if (total <= 0) {
                me.sizeLabel.text = @"";
                return;
            }
            if (pv > 0) {
                me.sizeLabel.text = [NSString stringWithFormat:@"约 %.1f MB", (total + pv) / 1048576.0];
            } else {
                me.sizeLabel.text = [NSString stringWithFormat:@"约 %.1f MB", total / 1048576.0];
            }
        });
    });
}

/// 逐条线路测一次延迟（拿 track.mp3 的首字节）
- (void)measureLatency
{
    NSArray *lines = AdxLines();
    NSMutableArray *urls = [NSMutableArray array];
    for (NSUInteger i = 0; i < lines.count; i++) {
        NSString *u = [self urlFor:@"track.mp3" host:lines[i][1]];
        [urls addObject:(u.length ? u : @"")];
    }

    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        for (NSUInteger i = 0; i < urls.count; i++) {
            NSString *u = urls[i];
            NSInteger ms = u.length ? [ADXChartDownloadSheet probeLatency:u] : -1;

            dispatch_async(dispatch_get_main_queue(), ^{
                __typeof(weakSelf) me = weakSelf;
                if (!me || i >= me.latency.count) return;
                me.latency[i] = @(ms < 0 ? -2 : ms);

                UILabel *lat = me.latencyLabels[i];
                lat.text = (ms < 0) ? @"不可用" : [NSString stringWithFormat:@"%ld ms", (long)ms];
                lat.textColor = (ms < 0) ? [UIColor tertiaryLabelColor] : [UIColor secondaryLabelColor];

                UILabel *dot = me.dots[i];
                dot.backgroundColor = (ms < 0) ? DRGB(255, 69, 58) : LatencyColor(ms);
            });
        }
    });
}

+ (NSInteger)probeLatency:(NSString *)url
{
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    req.timeoutInterval = 6;
    [req setValue:@"bytes=0-0" forHTTPHeaderField:@"Range"];

    __block NSInteger ms = -1;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    CFTimeInterval t0 = CFAbsoluteTimeGetCurrent();

    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            NSInteger code = 0;
            if ([resp isKindOfClass:[NSHTTPURLResponse class]]) code = [(NSHTTPURLResponse *)resp statusCode];
            if (!err && (code == 200 || code == 206)) {
                ms = (NSInteger)((CFAbsoluteTimeGetCurrent() - t0) * 1000.0);
            }
            dispatch_semaphore_signal(sem);
        }];
    [t resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC));
    return ms;
}

+ (long long)lengthOf:(NSString *)url
{
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    req.timeoutInterval = 10;
    [req setValue:@"bytes=0-0" forHTTPHeaderField:@"Range"];

    __block long long out = 0;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            if ([resp isKindOfClass:[NSHTTPURLResponse class]]) {
                NSString *cr = [(NSHTTPURLResponse *)resp allHeaderFields][@"Content-Range"];
                if (cr.length) {
                    NSRange slash = [cr rangeOfString:@"/"];
                    if (slash.location != NSNotFound)
                        out = [[cr substringFromIndex:slash.location + 1] longLongValue];
                }
                if (out == 0) out = resp.expectedContentLength;
            }
            dispatch_semaphore_signal(sem);
        }];
    [t resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 12 * NSEC_PER_SEC));
    return out;
}

#pragma mark - 下载

/// 蓝色按钮：正常是「开始下载」；导出完还没导入时，这里是「导入游戏」
- (void)startTapped
{
    // 下载中这颗按钮就是「取消下载」
    if (self.running) {
        [self cancelTapped];
        return;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    if (self.tmpFolder.length && ![self importedAlready] && [fm fileExistsAtPath:self.tmpFolder]) {
        [self importTapped];
        return;
    }
    if ([self importedAlready]) return;
    [self beginFlow:NO];
}

/// 中止本次下载：掐断正在传输的任务，删掉半截临时文件，按钮恢复「开始下载」
- (void)cancelTapped
{
    self.cancelled = YES;
    [self.task cancel];
    self.task = nil;

    [[NSFileManager defaultManager] removeItemAtPath:self.tmpRoot error:nil];
    self.tmpRoot = nil;
    self.tmpFolder = nil;

    [self finishWithText:@"已取消下载"];
}

- (BOOL)importedAlready
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if (self.importedPath.length && [fm fileExistsAtPath:self.importedPath]) return YES;

    // 重开面板时按惯例路径找一次，避免把同一首再下一遍
    if (!self.importedPath.length) {
        NSString *cand = [NSHomeDirectory() stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"Documents/levels/%@", [self folderName]]];
        if ([fm fileExistsAtPath:cand]) {
            self.importedPath = cand;
            self.lastPath = cand;
            return YES;
        }
    }
    return NO;
}

/// 把临时目录里的谱面搬进 levels（导出之后的「导入游戏」）
- (void)importTapped
{
    if (self.running) return;
    self.running = YES;

    self.startButton.enabled = NO;
    self.goButton.enabled = NO;
    self.optButton.enabled = NO;
    self.exportButton.enabled = NO;
    [self setStatus:@"正在导入…" progress:1.0];

    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *levels = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/levels"];
        [fm createDirectoryAtPath:levels withIntermediateDirectories:YES attributes:nil error:nil];

        NSString *finalPath = [ADXChartDownloadSheet uniquePath:
                               [levels stringByAppendingPathComponent:[weakSelf folderName]]];
        NSError *err = nil;
        BOOL ok = [fm moveItemAtPath:weakSelf.tmpFolder toPath:finalPath error:&err];

        if (ok) {
            weakSelf.importedPath = finalPath;
            weakSelf.lastPath = finalPath;
            weakSelf.tmpFolder = nil;
            [weakSelf finishWithText:@"谱面导入成功"];
        } else {
            [weakSelf finishWithText:[NSString stringWithFormat:@"导入失败：%@", err.localizedDescription ?: @"未知"]];
        }
    });
}

- (void)exportTapped
{
    // ① 已经导入过：直接打包 levels 里那份
    if ([self importedAlready]) {
        [self exportFolder:self.importedPath];
        return;
    }
    // ② 导出过一次、zip 还在：直接再分享，不重新下载
    if (self.pendingZip.length && [[NSFileManager defaultManager] fileExistsAtPath:self.pendingZip]) {
        [self shareFile:self.pendingZip];
        return;
    }
    // ③ 还什么都没下：走「导出」流程（下载 → 打包 → 分享，不导入）
    [self beginFlow:YES];
}

- (void)exportFolder:(NSString *)folder
{
    if (self.running) return;
    self.running = YES;

    self.startButton.enabled = NO;
    self.goButton.enabled = NO;
    self.optButton.enabled = NO;
    self.exportButton.enabled = NO;
    self.bar.hidden = NO;
    self.statusLabel.hidden = NO;
    self.bar.progress = 0;
    self.statusLabel.text = @"正在打包…";
    [self layoutCard];

    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *exports = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/exports"];
        [[NSFileManager defaultManager] createDirectoryAtPath:exports
                                  withIntermediateDirectories:YES attributes:nil error:nil];

        NSString *name = [folder lastPathComponent];
        NSString *zipPath = [[exports stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"zip"];
        zipPath = [ADXChartDownloadSheet uniquePath:zipPath];

        NSError *zerr = nil;
        BOOL ok = [ADXZip zipDirectory:folder to:zipPath error:&zerr];

        if (!ok) {
            [weakSelf finishWithText:[NSString stringWithFormat:@"打包失败：%@", zerr.localizedDescription ?: @"未知"]];
            return;
        }
        [weakSelf finishWithText:[NSString stringWithFormat:@"已导出 %@", [zipPath lastPathComponent]]];
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf shareFile:zipPath]; });
    });
}

- (void)beginFlow:(BOOL)exporting
{
    if (self.running) return;
    self.running = YES;
    self.cancelled = NO;

    [self cleanupTemp];                 // 上一轮残留先清掉

    // 主按钮变成「取消下载」，保持可点（这正是慢线路卡住时的出口）
    self.startButton.enabled = YES;
    [self.startButton setTitle:@"取消下载" forState:UIControlStateNormal];
    self.startButton.backgroundColor = [UIColor systemRedColor];

    self.goButton.enabled = NO;
    self.optButton.enabled = NO;
    self.exportButton.enabled = NO;
    self.bar.hidden = NO;
    self.statusLabel.hidden = NO;
    self.bar.progress = 0;
    self.statusLabel.text = @"准备中…";
    [self layoutCard];

    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [weakSelf runWithExport:exporting];
    });
}

- (void)setStatus:(NSString *)text progress:(CGFloat)p
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = text;
        [self.bar setProgress:p animated:YES];
        [self layoutCard];
    });
}

- (void)finishWithText:(NSString *)text
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.running = NO;
        self.statusLabel.text = text;
        self.goButton.enabled = YES;
        self.optButton.enabled = YES;
        self.exportButton.enabled = YES;

        // 蓝色按钮三态：已导入 / 导出后待导入 / 初始
        self.startButton.hidden = NO;
        if (self.importedPath.length) {
            self.startButton.enabled = NO;
            [self.startButton setTitle:@"已导入游戏" forState:UIControlStateNormal];
            self.startButton.backgroundColor = [UIColor systemGray3Color];
        } else if (self.tmpFolder.length) {
            self.startButton.enabled = YES;
            [self.startButton setTitle:@"导入游戏" forState:UIControlStateNormal];
            self.startButton.backgroundColor = [UIColor systemBlueColor];
        } else {
            self.startButton.enabled = YES;
            [self.startButton setTitle:@"开始下载" forState:UIControlStateNormal];
            self.startButton.backgroundColor = [UIColor systemBlueColor];
        }
        [self layoutCard];
    });
}

- (NSString *)folderName
{
    NSString *title = self.song[1];
    if (![title isKindOfClass:[NSString class]]) title = @"chart";
    NSString *name = [NSString stringWithFormat:@"%d %@", [self shortId], title];
    name = [name stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    return name;
}

- (void)runWithExport:(BOOL)exporting
{
    int shortId = [self shortId];
    int vid = [self versionId];
    NSString *folder = [self folderName];

    NSString *tmpRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"ADXDl-%@", [[NSUUID UUID] UUIDString]]];
    NSString *tmpDir = [tmpRoot stringByAppendingPathComponent:folder];
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir
                              withIntermediateDirectories:YES attributes:nil error:nil];

    NSMutableArray *names = [NSMutableArray arrayWithObjects:@"maidata.txt", @"track.mp3", @"bg.png", nil];
    if (self.bgaSwitch.isOn) [names addObject:@"pv.mp4"];

    NSArray *lines = AdxLines();
    CGFloat total = (CGFloat)names.count;

    for (NSUInteger i = 0; i < names.count; i++) {
        if (self.cancelled) return;
        NSString *name = names[i];
        NSString *dest = [tmpDir stringByAppendingPathComponent:name];
        BOOL ok = NO;

        for (NSUInteger k = 0; k < lines.count && !ok; k++) {
            if (self.cancelled) return;
            NSUInteger li = ((NSUInteger)self.line + k) % lines.count;
            NSString *u = [NSString stringWithFormat:@"https://%@/%d/%d/%@", lines[li][1], vid, shortId, name];

            [self setStatus:[NSString stringWithFormat:@"正在从 %@ 下载 %@（%lu/%lu）",
                             lines[li][0], name, (unsigned long)(i + 1), (unsigned long)names.count]
                   progress:(CGFloat)i / total];

            ok = [self fetch:u to:dest];
        }

        if (self.cancelled) return;

        if (!ok && [name isEqualToString:@"maidata.txt"]) {
            NSString *fallback = [NSString stringWithFormat:@"https://adxdls.saop.cc/adxcs/%d/maidata.txt", shortId];
            ok = [self fetch:fallback to:dest];
        }

        if (self.cancelled) return;

        if (!ok) {
            [[NSFileManager defaultManager] removeItemAtPath:tmpRoot error:nil];
            [self finishWithText:[NSString stringWithFormat:@"%@ 下载失败，已试过所有线路", name]];
            return;
        }

        [self setStatus:[NSString stringWithFormat:@"已完成 %lu/%lu", (unsigned long)(i + 1), (unsigned long)names.count]
               progress:(CGFloat)(i + 1) / total];
    }

    if (self.cancelled) return;

    if (exporting) {
        // 打包成 zip 放到 Documents/exports，然后弹分享。
        // 注意：不导入 levels，文件留在临时目录，等用户点「导入游戏」再搬。
        NSString *exports = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/exports"];
        [[NSFileManager defaultManager] createDirectoryAtPath:exports
                                  withIntermediateDirectories:YES attributes:nil error:nil];

        NSString *zipPath = [[exports stringByAppendingPathComponent:folder] stringByAppendingPathExtension:@"zip"];
        zipPath = [ADXChartDownloadSheet uniquePath:zipPath];

        NSError *zerr = nil;
        BOOL zipped = [ADXZip zipDirectory:tmpDir to:zipPath error:&zerr];

        if (!zipped) {
            [[NSFileManager defaultManager] removeItemAtPath:tmpRoot error:nil];
            [self finishWithText:[NSString stringWithFormat:@"打包失败：%@", zerr.localizedDescription ?: @"未知"]];
            return;
        }

        self.tmpRoot = tmpRoot;
        self.tmpFolder = tmpDir;
        self.pendingZip = zipPath;
        [self finishWithText:@"打包完成，可分享或点「导入游戏」"];
        dispatch_async(dispatch_get_main_queue(), ^{ [self shareFile:zipPath]; });
        return;
    }

    NSString *levels = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/levels"];
    [[NSFileManager defaultManager] createDirectoryAtPath:levels
                              withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *finalPath = [ADXChartDownloadSheet uniquePath:[levels stringByAppendingPathComponent:folder]];

    NSError *moveErr = nil;
    BOOL moved = [[NSFileManager defaultManager] moveItemAtPath:tmpDir toPath:finalPath error:&moveErr];
    [[NSFileManager defaultManager] removeItemAtPath:tmpRoot error:nil];

    if (moved) {
        self.importedPath = finalPath;
        self.lastPath = finalPath;
        [self finishWithText:@"谱面导入成功"];
    } else {
        [self finishWithText:[NSString stringWithFormat:@"导入失败：%@", moveErr.localizedDescription ?: @"未知"]];
    }
}

- (void)shareFile:(NSString *)path
{
    UIViewController *vc = self.window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    if (!vc) return;

    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]]
                                                                    applicationActivities:nil];
    av.popoverPresentationController.sourceView = self;
    av.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.bounds),
                                                             CGRectGetMidY(self.bounds), 1, 1);
    [vc presentViewController:av animated:YES completion:nil];
}

+ (NSString *)uniquePath:(NSString *)path
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return path;

    NSString *dir = [path stringByDeletingLastPathComponent];
    NSString *base = [[path lastPathComponent] stringByDeletingPathExtension];
    NSString *ext = [path pathExtension];
    for (int i = 2; i < 100; i++) {
        NSString *name = ext.length ? [NSString stringWithFormat:@"%@ (%d).%@", base, i, ext]
                                    : [NSString stringWithFormat:@"%@ (%d)", base, i];
        NSString *cand = [dir stringByAppendingPathComponent:name];
        if (![[NSFileManager defaultManager] fileExistsAtPath:cand]) return cand;
    }
    return path;
}

- (BOOL)fetch:(NSString *)url to:(NSString *)dest
{
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    req.timeoutInterval = 30;

    __block BOOL ok = NO;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            NSInteger code = 0;
            if ([resp isKindOfClass:[NSHTTPURLResponse class]]) code = [(NSHTTPURLResponse *)resp statusCode];
            if (!err && data.length > 128 && code == 200) {
                ok = [data writeToFile:dest atomically:YES];
            }
            dispatch_semaphore_signal(sem);
        }];
    self.task = t;
    [t resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 40 * NSEC_PER_SEC));
    if (self.task == t) self.task = nil;
    return ok && !self.cancelled;
}

@end
