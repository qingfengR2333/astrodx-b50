// B50Image.m — 1600×1502 的 B50 图，版式严格对齐最早的 PC 版
#import "B50Image.h"
#import "ChartDb.h"

static const CGFloat kPageW = 1600;
static const CGFloat kMargin = 36;
static const CGFloat kHeaderH = 152;
static const CGFloat kSectionH = 44;
static const CGFloat kBarH = 36;
static const CGFloat kCardW = 208;
static const CGFloat kCardH = 124;
static const CGFloat kGap = 12;
static const CGFloat kSectionGap = 26;
static const CGFloat kFooterH = 64;

// ---- 调色板（全部从 PC 版成图取色） ----
static UIColor *RGB(int r, int g, int b)
{
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}

static UIColor *RGBA(int r, int g, int b, CGFloat a)
{
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a];
}

// 卡片统一的深紫渐变（不随难度变化）
static UIColor *CardTop(void)  { return RGB(74, 62, 112); }   // #4A3E70
static UIColor *CardBot(void)  { return RGB(64, 53, 99); }    // #403563
static UIColor *TextDark(void) { return RGB(58, 46, 92); }    // #3A2E5C
static UIColor *Muted(void)    { return RGB(201, 190, 232); } // #C9BEE8
static UIColor *Gold(void)     { return RGB(255, 213, 94); }  // #FFD55E
static UIColor *Violet(void)   { return RGB(126, 96, 208); }  // #7E60D0
static UIColor *Pink(void)     { return RGB(226, 74, 125); }  // #E24A7D
static UIColor *PageBg(void)   { return RGB(243, 240, 251); }
static UIColor *PageBgTop(void){ return RGB(232, 226, 250); }

// ===== 难度配色 =====
// (1) 卡片主背景：绿 / 黄 / 红 / 紫 / 白
static void CardBG(int d, UIColor **top, UIColor **bot)
{
    switch (d) {
        case 2:  *top = RGB(46, 88, 60);      *bot = RGB(36, 72, 48);     return; // BASIC     深绿
        case 3:  *top = RGB(110, 88, 34);     *bot = RGB(90, 70, 26);     return; // ADVANCED  深黄
        case 4:  *top = RGB(124, 46, 54);     *bot = RGB(102, 36, 44);    return; // EXPERT    深红
        case 6:  *top = RGB(236, 236, 244);   *bot = RGB(220, 220, 232);  return; // RE:MASTER 白
        default: *top = CardTop();            *bot = CardBot();           return; // MASTER    深紫（不变）
    }
}

// 主背景上的文字：白卡用深灰，其余用白
static UIColor *CardInk(int d) { return (d == 6) ? RGB(52, 50, 66) : [UIColor whiteColor]; }

// 定数小字：跟主色同色系，避免紫灰压在绿/黄/红上发脏
static UIColor *CardSub(int d)
{
    switch (d) {
        case 2: return RGB(198, 228, 206);
        case 3: return RGB(238, 226, 190);
        case 4: return RGB(240, 202, 202);
        case 6: return RGB(112, 110, 132);
        default: return Muted();
    }
}

// 单曲 rating：深色卡片用金；白卡上换深一点的金，否则糊成一片
static UIColor *CardRating(int d) { return (d == 6) ? RGB(198, 146, 20) : Gold(); }

// (2) 难度小徽章：与主背景拉开明度差（深底配亮徽章 / 白底配深徽章）
static UIColor *BadgeFill(int d)
{
    switch (d) {
        case 2: return RGB(150, 224, 168);   // BASIC     亮绿
        case 3: return RGB(245, 210, 110);   // ADVANCED  亮黄
        case 4: return RGB(245, 138, 138);   // EXPERT    亮红
        case 5: return RGB(156, 92, 214);    // MASTER    紫
        case 6: return RGB(86, 84, 110);     // RE:MASTER 深灰
        default: return RGB(150, 140, 178);
    }
}

// 亮底徽章用深字，深底徽章用白字
static BOOL BadgeUsesDarkText(int d) { return d == 2 || d == 3 || d == 4; }

// 圆角条内文字的纵向视觉居中：拉丁按大写字高、中文按 0.88em 字形高度对齐
static CGFloat BarTextY(CGFloat barY, CGFloat barH, UIFont *f, BOOL cjk)
{
    CGFloat block = cjk ? f.pointSize * 0.88 : f.capHeight;
    return barY + (barH - block) / 2 - (f.ascender - block);
}

static void FillRound(CGRect r, CGFloat radius, UIColor *fill, UIColor *stroke, CGFloat lineW)
{
    UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius];
    if (fill) { [fill setFill]; [p fill]; }
    if (stroke && lineW > 0) { [stroke setStroke]; p.lineWidth = lineW; [p stroke]; }
}

// 竖直渐变填充圆角矩形
static void FillRoundGradient(CGRect r, CGFloat radius, UIColor *top, UIColor *bot)
{
    CGContextRef cg = UIGraphicsGetCurrentContext();
    CGContextSaveGState(cg);
    UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius];
    [p addClip];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[(id)top.CGColor, (id)bot.CGColor];
    CGGradientRef g = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, NULL);
    CGContextDrawLinearGradient(cg, g, CGPointMake(r.origin.x, r.origin.y),
                                CGPointMake(r.origin.x, CGRectGetMaxY(r)), 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(space);
    CGContextRestoreGState(cg);
}

@implementation ADXImage

#pragma mark - 曲绘

+ (NSString *)coverPath:(NSString *)dir songId:(int)sid
{
    return [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%05d.png", sid]];
}

+ (UIImage *)coverImageFor:(int)songId dir:(NSString *)dir
{
    if (songId <= 0 || !dir.length) return nil;

    NSString *path = [self coverPath:dir songId:songId];
    UIImage *img = [UIImage imageWithContentsOfFile:path];
    if (img) return img;

    if (![self downloadCover:songId to:dir]) return nil;
    return [UIImage imageWithContentsOfFile:path];
}

/// 日服独有曲目没有官方编号，直接按直链下载（缓存文件名仍用歌曲 id）；直链失败再退回 diving-fish
+ (UIImage *)coverImageFor:(int)songId url:(NSString *)url dir:(NSString *)dir
{
    if (songId <= 0 || !dir.length) return nil;

    NSString *path = [self coverPath:dir songId:songId];
    UIImage *img = [UIImage imageWithContentsOfFile:path];
    if (img) return img;

    if (url.length) {
        [self downloadURL:url to:path timeout:10];
        img = [UIImage imageWithContentsOfFile:path];
        if (img) return img;
    }

    // adxdls 上没有（或线路挂了）就退回 diving-fish
    if (![self downloadCover:songId to:dir]) return nil;
    return [UIImage imageWithContentsOfFile:path];
}

+ (BOOL)downloadURL:(NSString *)url to:(NSString *)path timeout:(NSTimeInterval)timeout
{
    NSURL *u = [NSURL URLWithString:url];
    if (!u || !path.length) return NO;

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block NSData *data = nil;
    NSURLSessionDataTask *t =
        [[NSURLSession sharedSession] dataTaskWithURL:u completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
            data = d;
            dispatch_semaphore_signal(sem);
        }];
    [t resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)));

    if (data.length < 200) return NO;

    [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return [data writeToFile:path atomically:YES];
}

+ (BOOL)downloadCover:(int)sid to:(NSString *)dir
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [self coverPath:dir songId:sid];
    if ([fm fileExistsAtPath:path]) return YES;

    int ids[2] = {sid, sid + 10000};
    for (int i = 0; i < 2; i++) {
        NSString *url = [NSString stringWithFormat:@"https://www.diving-fish.com/covers/%05d.png", ids[i]];
        NSURL *u = [NSURL URLWithString:url];
        if (!u) continue;

        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        __block NSData *data = nil;
        NSURLSessionDataTask *t =
            [[NSURLSession sharedSession] dataTaskWithURL:u completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
                data = d;
                dispatch_semaphore_signal(sem);
            }];
        [t resume];
        dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)));

        if (data.length > 200) {
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
            [data writeToFile:path atomically:YES];
            return YES;
        }
    }
    return NO;
}

+ (void)prefetch:(ADXB50Result *)r into:(NSString *)dir completion:(void (^)(void))done
{
    NSMutableArray *all = [NSMutableArray array];
    [all addObjectsFromArray:r.oldList];
    [all addObjectsFromArray:r.recentList];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        dispatch_group_t group = dispatch_group_create();
        dispatch_semaphore_t limit = dispatch_semaphore_create(6);
        for (ADXEntry *e in all) {
            if (e.songId <= 0) continue;
            if ([[NSFileManager defaultManager] fileExistsAtPath:[self coverPath:dir songId:e.songId]]) continue;
            NSString *url = [ADXChartDb coverURL:[ADXChartDb songById:e.songId]];
            dispatch_semaphore_wait(limit, DISPATCH_TIME_FOREVER);
            dispatch_group_enter(group);
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                if (url.length) [self coverImageFor:e.songId url:url dir:dir];
                else [self downloadCover:e.songId to:dir];
                dispatch_semaphore_signal(limit);
                dispatch_group_leave(group);
            });
        }
        dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(25 * NSEC_PER_SEC)));
        dispatch_async(dispatch_get_main_queue(), ^{ if (done) done(); });
    });
}

#pragma mark - 绘制

+ (UIImage *)draw:(ADXB50Result *)r coverDir:(NSString *)dir
{
    CGFloat pageH = kMargin + kHeaderH + 18
                  + (kSectionH + 5 * kCardH + 4 * kGap) + kSectionGap
                  + (kSectionH + 3 * kCardH + 2 * kGap)
                  + 18 + kFooterH + kMargin;

    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.scale = 1.0;
    fmt.opaque = YES;
    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(kPageW, pageH) format:fmt];

    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef cg = ctx.CGContext;

        // ==== 页面底色 + 顶部淡紫渐变 ====
        [PageBg() setFill];
        CGContextFillRect(cg, CGRectMake(0, 0, kPageW, pageH));
        {
            CGContextSaveGState(cg);
            CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
            UIColor *topColor = PageBgTop();
            UIColor *fillColor = PageBg();
            NSArray *cs = @[(id)topColor.CGColor, (id)fillColor.CGColor];
            CGGradientRef g = CGGradientCreateWithColors(space, (__bridge CFArrayRef)cs, NULL);
            CGContextDrawLinearGradient(cg, g, CGPointMake(0, 0), CGPointMake(0, pageH * 0.34), 0);
            CGGradientRelease(g);
            CGColorSpaceRelease(space);
            CGContextRestoreGState(cg);
        }

        // 右下角淡粉装饰圆
        UIBezierPath *blob =
            [UIBezierPath bezierPathWithRoundedRect:CGRectMake(kPageW - 420, pageH - 190, 520, 300)
                                       cornerRadius:140];
        [RGBA(226, 74, 125, 18.0 / 255.0) setFill];
        [blob fill];

        // ==== 头部 ====
        CGRect header = CGRectMake(kMargin, kMargin, kPageW - 2 * kMargin, kHeaderH);
        FillRoundGradient(header, 18, [UIColor whiteColor], RGB(248, 245, 255));
        FillRound(header, 18, nil, RGB(224, 217, 242), 1.2);

        // 左侧竖直强调条
        FillRound(CGRectMake(kMargin, kMargin + 24, 8, 105), 4, Violet(), nil, 0);

        NSMutableParagraphStyle *psLeft = [NSMutableParagraphStyle new];
        psLeft.lineBreakMode = NSLineBreakByClipping;

        // 标题 BEST 50（字高 45px）
        [@"BEST 50" drawInRect:CGRectMake(kMargin + 42, kMargin + 22, 600, 76)
                withAttributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:62.0],
                                 NSForegroundColorAttributeName: TextDark(),
                                 NSParagraphStyleAttributeName: psLeft}];

        NSDateFormatter *df = [NSDateFormatter new];
        df.dateFormat = @"yyyy-MM-dd HH:mm";
        NSString *sub = [NSString stringWithFormat:@"AstroDX 成绩估算 · %@", [df stringFromDate:[NSDate date]]];
        [sub drawInRect:CGRectMake(kMargin + 44, kMargin + 96, 700, 26)
         withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:20.0],
                          NSForegroundColorAttributeName: RGB(130, 120, 160),
                          NSParagraphStyleAttributeName: psLeft}];

        // 右侧 Rating
        NSMutableParagraphStyle *psRight = [NSMutableParagraphStyle new];
        psRight.alignment = NSTextAlignmentRight;

        NSString *total = [NSString stringWithFormat:@"%d", r.total];
        UIFont *bigFont = [UIFont boldSystemFontOfSize:72.0];
        CGSize bigSize = [total sizeWithAttributes:@{NSFontAttributeName: bigFont}];
        CGFloat rightPad = 38;
        CGFloat rx = kPageW - kMargin - rightPad;
        [total drawInRect:CGRectMake(rx - bigSize.width, kMargin + 18, bigSize.width + 8, 88)
           withAttributes:@{NSFontAttributeName: bigFont,
                            NSForegroundColorAttributeName: Pink()}];

        NSString *ratingWord = @"RATING";
        UIFont *rwFont = [UIFont boldSystemFontOfSize:17.0];
        CGSize rwSize = [ratingWord sizeWithAttributes:@{NSFontAttributeName: rwFont}];
        [ratingWord drawInRect:CGRectMake(rx - bigSize.width - rwSize.width - 18, kMargin + 51,
                                          rwSize.width + 6, 24)
                withAttributes:@{NSFontAttributeName: rwFont,
                                 NSForegroundColorAttributeName: RGB(150, 132, 190)}];

        NSString *eq = [NSString stringWithFormat:@"= 旧曲 %lu 首 %d  +  新曲 %lu 首 %d",
                        (unsigned long)r.oldList.count, r.oldSum,
                        (unsigned long)r.recentList.count, r.newSum];
        [eq drawInRect:CGRectMake(kMargin, kMargin + 102, kPageW - 2 * kMargin - rightPad, 28)
        withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:19.0],
                         NSForegroundColorAttributeName: RGB(150, 140, 180),
                         NSParagraphStyleAttributeName: psRight}];

        // ==== 两段 ====
        CGFloat y = kMargin + kHeaderH + 18;
        y = [self drawSection:r list:r.oldList sum:r.oldSum index:1 name:@"BEST 35"
                      caption:@"旧曲 · 最佳 35 首" y:y rows:5 coverDir:dir cols:7];
        y += kSectionGap;
        y = [self drawSection:r list:r.recentList sum:r.newSum index:2 name:@"BEST 15"
                      caption:@"新曲 · 最佳 15 首" y:y rows:3 coverDir:dir cols:5];

        // ==== 页脚 ====
        CGFloat fy = pageH - kMargin - kFooterH + 12;
        NSString *left = [NSString stringWithFormat:@"由 AstroDX B50 生成 · 定数来自 lxns 曲库 · 当前版本 %d", r.current];
        [left drawInRect:CGRectMake(kMargin, fy, 1000, 26)
          withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:17.0],
                           NSForegroundColorAttributeName: RGB(130, 122, 158)}];
        NSString *right = [NSString stringWithFormat:@"未识别 %d 首不参与计算（自制谱 / 宴会场）", r.unmatched];
        // 居中对齐到右下角淡粉半圆的可见区域内（x 1180..1600，中心 1390）
        NSMutableParagraphStyle *psCenter = [NSMutableParagraphStyle new];
        psCenter.alignment = NSTextAlignmentCenter;
        [right drawInRect:CGRectMake(kPageW - 420, fy, 420, 26)
           withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:17.0],
                            NSForegroundColorAttributeName: RGB(130, 122, 158),
                            NSParagraphStyleAttributeName: psCenter}];
    }];
}

+ (CGFloat)drawSection:(ADXB50Result *)r list:(NSArray *)list sum:(int)sum index:(int)idx
                  name:(NSString *)name caption:(NSString *)caption y:(CGFloat)y rows:(int)rows
              coverDir:(NSString *)dir cols:(int)cols
{
    // 01 紫 / 02 粉，纯色，白字
    UIColor *barFill = (idx == 1) ? Violet() : Pink();
    CGRect bar = CGRectMake(kMargin, y, kPageW - 2 * kMargin, kBarH);
    FillRound(bar, 14, barFill, nil, 0);

    NSMutableParagraphStyle *psL = [NSMutableParagraphStyle new];
    psL.lineBreakMode = NSLineBreakByClipping;
    NSString *title = [NSString stringWithFormat:@"0%d.  %@", idx, name];
    UIFont *tf = [UIFont boldSystemFontOfSize:26.0];
    [title drawInRect:CGRectMake(kMargin + 20, BarTextY(y, kBarH, tf, NO), 500, 34)
       withAttributes:@{NSFontAttributeName: tf,
                        NSForegroundColorAttributeName: [UIColor whiteColor],
                        NSParagraphStyleAttributeName: psL}];

    NSMutableParagraphStyle *psR = [NSMutableParagraphStyle new];
    psR.alignment = NSTextAlignmentRight;
    NSString *rightText = list.count
        ? [NSString stringWithFormat:@"%@ · 合计 %d · 平均 %d", caption, sum, sum / (int)list.count]
        : [NSString stringWithFormat:@"%@ · 没有可计入的谱面", caption];
    UIFont *sf = [UIFont systemFontOfSize:19.0];
    [rightText drawInRect:CGRectMake(kMargin, BarTextY(y, kBarH, sf, YES), kPageW - 2 * kMargin - 22, 26)
            withAttributes:@{NSFontAttributeName: sf,
                             NSForegroundColorAttributeName: RGBA(255, 255, 255, 0.94),
                             NSParagraphStyleAttributeName: psR}];

    // 起点固定按 7 列算，BEST 15 才会和 BEST 35 左边对齐
    int innerW = 7 * kCardW + 6 * kGap;
    CGFloat startX = kMargin + (kPageW - 2 * kMargin - innerW) / 2;

    for (int row = 0; row < rows; row++) {
        for (int col = 0; col < cols; col++) {
            int i = row * cols + col;
            CGRect card = CGRectMake(startX + col * (kCardW + kGap),
                                     y + kSectionH + row * (kCardH + kGap),
                                     kCardW, kCardH);
            if (i < (int)list.count) [self drawCard:list[i] in:card coverDir:dir];
            else [self drawEmptyCard:card];
        }
    }
    return y + kSectionH + rows * kCardH + (rows - 1) * kGap;
}

+ (void)drawCard:(ADXEntry *)e in:(CGRect)card coverDir:(NSString *)dir
{
    int d = e.diffId;
    CGContextRef cg = UIGraphicsGetCurrentContext();
    // 必须保存/恢复图形状态：addClip 会一直生效
    CGContextSaveGState(cg);

    // 主背景按难度取色（深紫 / 深绿 / 深黄 / 深红 / 白），无边框
    UIColor *bgTop = nil, *bgBot = nil;
    CardBG(e.diffId, &bgTop, &bgBot);
    FillRoundGradient(card, 10, bgTop, bgBot);

    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:card cornerRadius:10];
    [path addClip];

    // ---- 曲绘 66×66 ----
    CGRect coverRect = CGRectMake(card.origin.x + 8, card.origin.y + 8, 66, 66);
    UIBezierPath *clip = [UIBezierPath bezierPathWithRoundedRect:coverRect cornerRadius:6];
    UIImage *img = nil;
    if (e.songId > 0)
        img = [UIImage imageWithContentsOfFile:[self coverPath:dir songId:e.songId]];
    if (!img && e.songId > 0) {
        // 缓存里没有（多半是 diving-fish 没这首）→ 现场按 adxdls 直链补一次
        NSString *url = [ADXChartDb coverURL:[ADXChartDb songById:e.songId]];
        if (url.length) img = [self coverImageFor:e.songId url:url dir:dir];
    }

    CGContextSaveGState(cg);
    [clip addClip];
    if (img) {
        CGFloat s = MAX(coverRect.size.width / img.size.width, coverRect.size.height / img.size.height);
        CGRect r = CGRectMake(coverRect.origin.x - (img.size.width * s - coverRect.size.width) / 2,
                              coverRect.origin.y - (img.size.height * s - coverRect.size.height) / 2,
                              img.size.width * s, img.size.height * s);
        [img drawInRect:r];
    } else {
        [((d == 6) ? RGB(228, 228, 238) : RGB(52, 42, 80)) setFill];
        UIRectFill(coverRect);
        NSString *ch = e.title.length ? [e.title substringToIndex:1] : @"?";
        UIFont *cf = [UIFont boldSystemFontOfSize:34.0];
        CGSize cs = [ch sizeWithAttributes:@{NSFontAttributeName: cf}];
        [ch drawAtPoint:CGPointMake(CGRectGetMidX(coverRect) - cs.width / 2,
                                    CGRectGetMidY(coverRect) - cs.height / 2)
         withAttributes:@{NSFontAttributeName: cf,
                          NSForegroundColorAttributeName: ((d == 6) ? RGB(150, 148, 172)
                                                                     : RGB(150, 140, 190))}];
    }
    CGContextRestoreGState(cg);

    // ---- 排名角标（压在曲绘左下） ----
    FillRound(CGRectMake(card.origin.x + 8, card.origin.y + 59, 34, 15), 4,
              [UIColor colorWithWhite:0 alpha:0.66], nil, 0);
    [[NSString stringWithFormat:@"#%d", e.rank] drawAtPoint:CGPointMake(card.origin.x + 11, card.origin.y + 59.5)
        withAttributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:10.5],
                         NSForegroundColorAttributeName: [UIColor whiteColor]}];

    // ---- 曲名：两行，行高 19 ----
    CGFloat tw = kCardW - 84;
    NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
    ps.lineBreakMode = NSLineBreakByTruncatingTail;
    ps.minimumLineHeight = 19;
    ps.maximumLineHeight = 19;
    UIFont *titleFont = [UIFont boldSystemFontOfSize:15.0];
    NSDictionary *titleAttr = @{NSFontAttributeName: titleFont,
                                NSForegroundColorAttributeName: CardInk(d),
                                NSParagraphStyleAttributeName: ps};
    [e.title drawInRect:CGRectMake(card.origin.x + 80, card.origin.y + 8, tw, 40)
         withAttributes:titleAttr];

    // ---- 难度徽章 + 定数 ----
    NSString *lvl = e.level.length ? e.level : @"?";
    UIFont *bf = [UIFont boldSystemFontOfSize:12.0];
    CGFloat bw = MAX(30, [lvl sizeWithAttributes:@{NSFontAttributeName: bf}].width + 14);
    BOOL darkBadge = BadgeUsesDarkText(d);
    FillRound(CGRectMake(card.origin.x + 8, card.origin.y + 82, bw, 17), 5,
              BadgeFill(d), nil, 0);
    CGSize ls = [lvl sizeWithAttributes:@{NSFontAttributeName: bf}];
    [lvl drawAtPoint:CGPointMake(card.origin.x + 8 + (bw - ls.width) / 2, card.origin.y + 83)
      withAttributes:@{NSFontAttributeName: bf,
                       NSForegroundColorAttributeName: darkBadge ? RGB(46, 52, 44) : [UIColor whiteColor]}];

    [[NSString stringWithFormat:@"%.1f", e.ds] drawAtPoint:CGPointMake(card.origin.x + 8 + bw + 8,
                                                                     card.origin.y + 84)
        withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:14.0],
                         NSForegroundColorAttributeName: CardSub(d)}];

    // ---- 达成率（粗体，颜色跟主背景走） ----
    [[NSString stringWithFormat:@"%.4f%%", e.rate] drawAtPoint:CGPointMake(card.origin.x + 8,
                                                                         card.origin.y + 97)
        withAttributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:21.0],
                         NSForegroundColorAttributeName: CardInk(d)}];

    // ---- 单曲 Rating（金色，右对齐） ----
    NSMutableParagraphStyle *psRt = [NSMutableParagraphStyle new];
    psRt.alignment = NSTextAlignmentRight;
    NSString *ra = [NSString stringWithFormat:@"%d", e.rating];
    [ra drawInRect:CGRectMake(card.origin.x + 8, card.origin.y + 95, kCardW - 16, 30)
        withAttributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:23.0],
                         NSForegroundColorAttributeName: CardRating(d),
                         NSParagraphStyleAttributeName: psRt}];

    CGContextRestoreGState(cg);
}

+ (void)drawEmptyCard:(CGRect)card
{
    FillRound(card, 10, RGB(238, 234, 248), RGB(222, 214, 240), 1.2);
    NSString *dash = @"—";
    UIFont *f = [UIFont boldSystemFontOfSize:22.0];
    CGSize s = [dash sizeWithAttributes:@{NSFontAttributeName: f}];
    [dash drawAtPoint:CGPointMake(CGRectGetMidX(card) - s.width / 2, CGRectGetMidY(card) - s.height / 2)
       withAttributes:@{NSFontAttributeName: f, NSForegroundColorAttributeName: RGB(190, 182, 210)}];
}

#pragma mark - 入口

+ (void)render:(ADXB50Result *)result
      coverDir:(NSString *)coverDir
        toPath:(NSString *)path
    completion:(void (^)(UIImage *, NSError *))completion
{
    if (!result) {
        if (completion) completion(nil, [NSError errorWithDomain:@"ADXImage" code:1
                                                        userInfo:@{NSLocalizedDescriptionKey: @"没有 B50 数据"}]);
        return;
    }
    [self prefetch:result into:coverDir completion:^{
        UIImage *img = [self draw:result coverDir:coverDir];
        if (!img) {
            if (completion) completion(nil, [NSError errorWithDomain:@"ADXImage" code:2
                                                            userInfo:@{NSLocalizedDescriptionKey: @"绘制失败"}]);
            return;
        }
        [UIImagePNGRepresentation(img) writeToFile:path atomically:YES];
        if (completion) completion(img, nil);
    }];
}

@end
