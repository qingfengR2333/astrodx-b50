// ChartDownloadSheet.m — 谱面下载：adxdls 的线路 + 直链文件，下载完直接落进 levels
#import "ChartDownloadSheet.h"
#import "ChartDb.h"

static UIColor *DRGB(CGFloat r, CGFloat g, CGFloat b)
{
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}

/// 站点右上角「设置」里的线路，顺序即兜底顺序
static NSArray *AdxLines(void)
{
    return @[@[@"R2", @"astrodx-charts.saop.cc", @"推荐"],
             @[@"Alice", @"astrodx-charts-alice.saop.cc", @"备用"],
             @[@"G510", @"astrodx-charts-g510.saop.cc", @"备用"],
             @[@"WMC", @"astrodx-charts-wmc.saop.cc", @"备用"],
             @[@"Tsumugi", @"astrodx-charts-tsumugi.saop.cc", @"备用"]];
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

@interface ADXChartDownloadSheet ()

@property (nonatomic, strong) UIView *dim;
@property (nonatomic, strong) UIView *card;

@property (nonatomic, strong) UIButton *goButton;      // 站内下载 .zip
@property (nonatomic, strong) UIButton *optButton;     // 下载选项
@property (nonatomic, strong) UILabel *sizeLabel;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIView *bgaRow;
@property (nonatomic, strong) UISwitch *bgaSwitch;
@property (nonatomic, strong) UIProgressView *bar;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *startButton;

@property (nonatomic, strong) NSArray *song;
@property (nonatomic, assign) BOOL isDx;
@property (nonatomic, assign) BOOL panelOpen;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) NSInteger line;
@property (nonatomic, strong) NSMutableArray *lineChecks;

+ (long long)lengthOf:(NSString *)url;
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
    sheet.lineChecks = [NSMutableArray array];

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
}

- (void)close
{
    if (self.running) return;   // 下载中不关，避免半截文件
    __weak __typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.15 animations:^{ weakSelf.alpha = 0; } completion:^(BOOL done) {
        [weakSelf removeFromSuperview];
    }];
}

#pragma mark - 界面

- (void)build
{
    CGFloat w = MIN(520, self.bounds.size.width - 56);

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake((self.bounds.size.width - w) / 2, 0, w, 300)];
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 16;
    card.layer.masksToBounds = YES;
    [self addSubview:card];
    self.card = card;

    CGFloat pad = 20;
    CGFloat inner = w - pad * 2;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(pad, 18, inner, 24)];
    title.text = @"下载谱面";
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    [card addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(pad, 44, inner, 18)];
    sub.text = [NSString stringWithFormat:@"%@ · %@", self.song[1],
                [ADXChartDb versionText:self.song dx:self.isDx]];
    sub.font = [UIFont systemFontOfSize:12];
    sub.textColor = [UIColor secondaryLabelColor];
    sub.lineBreakMode = NSLineBreakByTruncatingTail;
    [card addSubview:sub];

    // 站内下载 .zip
    self.goButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.goButton.frame = CGRectMake(pad, 76, 168, 40);
    [self.goButton setTitle:@"⤓  站内下载 .zip" forState:UIControlStateNormal];
    self.goButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.goButton.backgroundColor = DRGB(110, 124, 240);
    [self.goButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.goButton.layer.cornerRadius = 9;
    [self.goButton addTarget:self action:@selector(startTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.goButton];

    // 下载选项
    self.optButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.optButton.frame = CGRectMake(pad + 178, 76, 118, 40);
    [self.optButton setTitle:@"下载选项 ⌄" forState:UIControlStateNormal];
    self.optButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.optButton.backgroundColor = [UIColor tertiarySystemFillColor];
    [self.optButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    self.optButton.layer.cornerRadius = 9;
    [self.optButton addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.optButton];

    self.sizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad + 306, 76, inner - 306, 40)];
    self.sizeLabel.text = @"正在计算…";
    self.sizeLabel.font = [UIFont systemFontOfSize:12];
    self.sizeLabel.textColor = [UIColor secondaryLabelColor];
    [card addSubview:self.sizeLabel];

    [self buildPanelIn:card width:inner x:pad];

    // 包含 BGA
    UIView *bga = [[UIView alloc] initWithFrame:CGRectMake(pad, 0, inner, 40)];
    UILabel *bgaTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 2, inner - 60, 18)];
    bgaTitle.text = @"包含 BGA 视频";
    bgaTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [bga addSubview:bgaTitle];

    UILabel *bgaNote = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, inner - 60, 16)];
    bgaNote.text = @"只影响背景动画，不影响谱面游玩。";
    bgaNote.font = [UIFont systemFontOfSize:11.5];
    bgaNote.textColor = [UIColor tertiaryLabelColor];
    [bga addSubview:bgaNote];

    self.bgaSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(inner - 51, 6, 51, 31)];
    self.bgaSwitch.on = YES;
    self.bgaSwitch.transform = CGAffineTransformMakeScale(0.82, 0.82);
    [bga addSubview:self.bgaSwitch];

    [card addSubview:bga];
    self.bgaRow = bga;

    self.bar = [[UIProgressView alloc] initWithFrame:CGRectMake(pad, 0, inner, 4)];
    self.bar.progress = 0;
    self.bar.hidden = YES;
    [card addSubview:self.bar];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, 0, inner, 18)];
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

    NSArray *lines = AdxLines();
    CGFloat y = 6;
    for (NSUInteger i = 0; i < lines.count; i++) {
        NSArray *l = lines[i];
        UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
        row.frame = CGRectMake(0, y, inner, 34);
        row.tag = (NSInteger)i;
        [row addTarget:self action:@selector(lineTapped:) forControlEvents:UIControlEventTouchUpInside];

        UILabel *dot = [[UILabel alloc] initWithFrame:CGRectMake(0, 11, 8, 8)];
        dot.backgroundColor = DRGB(232, 152, 40);
        dot.layer.cornerRadius = 4;
        dot.layer.masksToBounds = YES;
        dot.tag = 700;
        [row addSubview:dot];

        UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(16, 4, 120, 18)];
        name.text = l[0];
        name.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        name.tag = 701;
        [row addSubview:name];

        UILabel *tag = [[UILabel alloc] initWithFrame:CGRectMake(16 + 66, 6, 44, 16)];
        tag.text = l[2];
        tag.font = [UIFont systemFontOfSize:10];
        tag.textColor = [UIColor secondaryLabelColor];
        tag.textAlignment = NSTextAlignmentCenter;
        tag.backgroundColor = [UIColor tertiarySystemFillColor];
        tag.layer.cornerRadius = 4;
        tag.layer.masksToBounds = YES;
        [row addSubview:tag];

        UILabel *check = [[UILabel alloc] initWithFrame:CGRectMake(inner - 24, 4, 24, 18)];
        check.text = @"✓";
        check.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        check.textColor = [UIColor systemBlueColor];
        check.textAlignment = NSTextAlignmentRight;
        check.tag = 702;
        check.hidden = (i != 0);
        [row addSubview:check];

        [panel addSubview:row];
        [self.lineChecks addObject:check];
        y += 34;
    }

    UILabel *note = [[UILabel alloc] initWithFrame:CGRectMake(0, y + 2, inner, 16)];
    note.text = @"R2 为主线路；下载失败会自动换到下一条。";
    note.font = [UIFont systemFontOfSize:11];
    note.textColor = [UIColor tertiaryLabelColor];
    [panel addSubview:note];

    panel.frame = CGRectMake(pad, 124, inner, 0);
    panel.tag = 999;
}

- (void)layoutCard
{
    CGFloat w = self.card.bounds.size.width;
    CGFloat pad = 20;
    CGFloat inner = w - pad * 2;

    CGFloat panelH = self.panelOpen ? (6 + 34 * AdxLines().count + 20) : 0;
    self.panel.frame = CGRectMake(pad, 124, inner, panelH);

    // 说明文字贴在 panel 底部（panel 里唯一的直接 UILabel）
    for (UIView *v in self.panel.subviews) {
        if ([v isKindOfClass:[UILabel class]])
            v.frame = CGRectMake(0, 34 * AdxLines().count + 2, inner, 16);
    }

    CGFloat y = 124 + panelH + 4;
    self.bgaRow.frame = CGRectMake(pad, y, inner, 40);
    y += 40;

    if (!self.bar.hidden) {
        self.bar.frame = CGRectMake(pad, y + 4, inner, 4);
        self.statusLabel.frame = CGRectMake(pad, y + 12, inner, 20);
        y += 38;
    }

    if (!self.startButton.hidden) {
        self.startButton.frame = CGRectMake(pad, y + 8, inner, 44);
        y += 8 + 44;
    }
    y += 20;

    CGRect f = self.card.frame;
    f.size.height = y;
    f.origin.y = round((self.bounds.size.height - y) / 2);
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
    for (NSUInteger i = 0; i < self.lineChecks.count; i++) {
        UILabel *c = self.lineChecks[i];
        c.hidden = (i != (NSUInteger)self.line);
    }
}

#pragma mark - 计算大小

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
    if (idx == NSNotFound) {
        // 没有日服版本信息时，按国服版本名粗估一个，保证路径不至于全错
        return 27;
    }
    return (int)idx;
}

- (NSString *)fileURL:(NSString *)name host:(NSString *)host
{
    return [NSString stringWithFormat:@"https://%@/%d/%d/%@", host, [self versionId], [self shortId], name];
}

- (void)measureSize
{
    NSString *host = AdxLines()[0][1];
    NSArray *probes = @[[self fileURL:@"track.mp3" host:host], [self fileURL:@"bg.png" host:host]];

    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        long long total = 0;
        for (NSString *u in probes) {
            long long n = [ADXChartDownloadSheet lengthOf:u];
            if (n > 0) total += n;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            __typeof(weakSelf) me = weakSelf;
            if (!me) return;
            if (total <= 0) {
                me.sizeLabel.text = @"";
            } else {
                me.sizeLabel.text = [NSString stringWithFormat:@"约 %.1f MB", total / 1048576.0];
            }
        });
    });
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

- (void)startTapped
{
    if (self.running) return;
    self.running = YES;

    self.startButton.enabled = NO;
    self.goButton.enabled = NO;
    self.optButton.enabled = NO;
    self.bar.hidden = NO;
    self.statusLabel.hidden = NO;
    self.bar.progress = 0;
    self.statusLabel.text = @"准备中…";
    [self layoutCard];

    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [weakSelf runDownload];
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

- (void)runDownload
{
    int shortId = [self shortId];
    int vid = [self versionId];

    NSString *title = self.song[1];
    if (![title isKindOfClass:[NSString class]]) title = @"chart";
    NSString *folderName = [NSString stringWithFormat:@"%d %@", shortId, title];
    folderName = [folderName stringByReplacingOccurrencesOfString:@"/" withString:@"-"];

    NSString *tmpRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"ADXDl-%@", [[NSUUID UUID] UUIDString]]];
    NSString *tmpDir = [tmpRoot stringByAppendingPathComponent:folderName];
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir
                              withIntermediateDirectories:YES attributes:nil error:nil];

    NSMutableArray *names = [NSMutableArray arrayWithObjects:@"maidata.txt", @"track.mp3", @"bg.png", nil];
    if (self.bgaSwitch.isOn) [names addObject:@"pv.mp4"];

    NSArray *lines = AdxLines();
    CGFloat total = (CGFloat)names.count;

    for (NSUInteger i = 0; i < names.count; i++) {
        NSString *name = names[i];
        NSString *dest = [tmpDir stringByAppendingPathComponent:name];
        BOOL ok = NO;

        // 先从选中的线路开始，失败依次换线
        for (NSUInteger k = 0; k < lines.count && !ok; k++) {
            NSUInteger li = ((NSUInteger)self.line + k) % lines.count;
            NSString *host = lines[li][1];
            NSString *u = [NSString stringWithFormat:@"https://%@/%d/%d/%@", host, vid, shortId, name];

            [self setStatus:[NSString stringWithFormat:@"正在从 %@ 下载 %@（%lu/%lu）",
                             lines[li][0], name, (unsigned long)(i + 1), (unsigned long)names.count]
                   progress:(CGFloat)i / total];

            ok = [self fetch:u to:dest];
        }

        // maidata 只有镜像站有，主站 404 时退回站点自己的 /adxcs
        if (!ok && [name isEqualToString:@"maidata.txt"]) {
            NSString *fallback = [NSString stringWithFormat:@"https://adxdls.saop.cc/adxcs/%d/maidata.txt", shortId];
            ok = [self fetch:fallback to:dest];
        }

        if (!ok) {
            [[NSFileManager defaultManager] removeItemAtPath:tmpRoot error:nil];
            self.running = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                self.startButton.enabled = YES;
                self.goButton.enabled = YES;
                self.optButton.enabled = YES;
                self.statusLabel.text = [NSString stringWithFormat:@"%@ 下载失败，已试过所有线路", name];
                [self layoutCard];
            });
            return;
        }

        [self setStatus:[NSString stringWithFormat:@"已完成 %lu/%lu", (unsigned long)(i + 1), (unsigned long)names.count]
               progress:(CGFloat)(i + 1) / total];
    }

    // 落到 Documents/levels
    NSString *levels = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/levels"];
    [[NSFileManager defaultManager] createDirectoryAtPath:levels
                              withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *finalPath = [levels stringByAppendingPathComponent:folderName];
    finalPath = [ADXChartDownloadSheet uniquePath:finalPath];

    NSError *moveErr = nil;
    BOOL moved = [[NSFileManager defaultManager] moveItemAtPath:tmpDir toPath:finalPath error:&moveErr];
    [[NSFileManager defaultManager] removeItemAtPath:tmpRoot error:nil];

    self.running = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.bar setProgress:1.0 animated:YES];
        if (moved) {
            self.statusLabel.text = [NSString stringWithFormat:@"已导入 levels/%@", [finalPath lastPathComponent]];
        } else {
            self.statusLabel.text = [NSString stringWithFormat:@"导入失败：%@", moveErr.localizedDescription ?: @"未知"];
        }
        self.startButton.enabled = YES;
        self.startButton.hidden = YES;
        self.goButton.enabled = YES;
        self.optButton.enabled = YES;
        [self layoutCard];
    });
}

+ (NSString *)uniquePath:(NSString *)path
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return path;

    NSString *dir = [path stringByDeletingLastPathComponent];
    NSString *base = [path lastPathComponent];
    for (int i = 2; i < 100; i++) {
        NSString *cand = [dir stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@ (%d)", base, i]];
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
    [t resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 40 * NSEC_PER_SEC));
    return ok;
}

@end
