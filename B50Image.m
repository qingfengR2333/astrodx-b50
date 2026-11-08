// B50Image.m — 1600×1502 的 B50 图，版式与 PC 版一致
#import "B50Image.h"

static const CGFloat kPageW = 1600;
static const CGFloat kMargin = 36;
static const CGFloat kHeaderH = 152;
static const CGFloat kSectionH = 44;
static const CGFloat kCardW = 208;
static const CGFloat kCardH = 124;
static const CGFloat kGap = 12;
static const CGFloat kSectionGap = 26;
static const CGFloat kFooterH = 64;

static UIColor *RGB(int r, int g, int b)
{
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}

static UIColor *Shade(UIColor *c, CGFloat f)
{
    CGFloat r, g, b, a;
    if (![c getRed:&r green:&g blue:&b alpha:&a]) return c;
    return [UIColor colorWithRed:MIN(1, r * f) green:MIN(1, g * f) blue:MIN(1, b * f) alpha:a];
}

static UIColor *DiffColor(int d)
{
    switch (d) {
        case 2: return RGB(58, 140, 72);    // BASIC 绿
        case 3: return RGB(206, 154, 38);   // ADVANCED 黄
        case 4: return RGB(198, 66, 70);    // EXPERT 红
        case 5: return RGB(116, 74, 178);   // MASTER 紫
        case 6: return RGB(228, 228, 238);  // RE:MASTER 白
        default: return RGB(140, 130, 165);
    }
}

static BOOL IsLightCard(int d) { return d == 6; }

static void FillRound(CGRect r, CGFloat radius, UIColor *fill, UIColor *stroke, CGFloat lineW)
{
    UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius];
    if (fill) { [fill setFill]; [p fill]; }
    if (stroke && lineW > 0) { [stroke setStroke]; p.lineWidth = lineW; [p stroke]; }
}

@implementation ADXImage

#pragma mark - 曲绘

+ (NSString *)coverPath:(NSString *)dir songId:(int)sid
{
    return [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%05d.png", sid]];
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
            dispatch_semaphore_wait(limit, DISPATCH_TIME_FOREVER);
            dispatch_group_enter(group);
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                [self downloadCover:e.songId to:dir];
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

        // 背景
        [RGB(243, 240, 251) setFill];
        CGContextFillRect(cg, CGRectMake(0, 0, kPageW, pageH));

        // 右下角淡粉装饰圆（和 PC 版一致，压在「未识别」那行字下面）
        UIBezierPath *blob =
            [UIBezierPath bezierPathWithRoundedRect:CGRectMake(kPageW - 420, pageH - 190, 520, 300)
                                       cornerRadius:140];
        [[RGB(226, 74, 125) colorWithAlphaComponent:18.0 / 255.0] setFill];
        [blob fill];

        // ---- 头部 ----
        CGRect header = CGRectMake(kMargin, kMargin, kPageW - 2 * kMargin, kHeaderH);
        FillRound(header, 18, [UIColor whiteColor], RGB(220, 212, 240), 1.4);
        FillRound(CGRectMake(kMargin, kMargin + 22, 8, kHeaderH - 44), 4, RGB(126, 96, 208), nil, 0);

        NSMutableParagraphStyle *psLeft = [NSMutableParagraphStyle new];
        [[NSString stringWithFormat:@"BEST 50"] drawInRect:CGRectMake(kMargin + 26, kMargin + 14, 560, 52)
            withAttributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:40.0],
                             NSForegroundColorAttributeName: RGB(58, 46, 92),
                             NSParagraphStyleAttributeName: psLeft}];

        NSDateFormatter *df = [NSDateFormatter new];
        df.dateFormat = @"yyyy-MM-dd HH:mm";
        NSString *sub = [NSString stringWithFormat:@"AstroDX 成绩估算 · %@", [df stringFromDate:[NSDate date]]];
        [sub drawInRect:CGRectMake(kMargin + 30, kMargin + 86, 620, 22)
            withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12.0],
                             NSForegroundColorAttributeName: RGB(130, 120, 160)}];

        // 右侧 Rating
        NSMutableParagraphStyle *psRight = [NSMutableParagraphStyle new];
        psRight.alignment = NSTextAlignmentRight;
        NSString *total = [NSString stringWithFormat:@"%d", r.total];
        UIFont *bigFont = [UIFont boldSystemFontOfSize:45.3];
        CGSize bigSize = [total sizeWithAttributes:@{NSFontAttributeName: bigFont}];
        CGFloat rx = kPageW - kMargin - 26;
        [total drawInRect:CGRectMake(rx - bigSize.width, kMargin + 8, bigSize.width + 4, 58)
            withAttributes:@{NSFontAttributeName: bigFont,
                             NSForegroundColorAttributeName: RGB(226, 74, 125)}];
        NSString *ratingWord = @"RATING";
        CGSize rwSize = [ratingWord sizeWithAttributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:14.7]}];
        [ratingWord drawInRect:CGRectMake(rx - bigSize.width - rwSize.width - 16, kMargin + 28, rwSize.width + 4, 24)
            withAttributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:14.7],
                             NSForegroundColorAttributeName: RGB(150, 132, 190)}];

        NSString *eq = [NSString stringWithFormat:@"= 旧曲 %lu 首 %d  +  新曲 %lu 首 %d",
                        (unsigned long)r.oldList.count, r.oldSum,
                        (unsigned long)r.recentList.count, r.newSum];
        [eq drawInRect:CGRectMake(kMargin, kMargin + 96, kPageW - 2 * kMargin - 26, 20)
            withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12.0],
                             NSForegroundColorAttributeName: RGB(120, 110, 150),
                             NSParagraphStyleAttributeName: psRight}];

        // ---- 两段 ----
        CGFloat y = kMargin + kHeaderH + 18;
        y = [self drawSection:r list:r.oldList sum:r.oldSum index:1 name:@"BEST 35"
                      caption:@"旧曲 · 最佳 35 首" y:y rows:5 coverDir:dir cols:7];
        y += kSectionGap;
        y = [self drawSection:r list:r.recentList sum:r.newSum index:2 name:@"BEST 15"
                      caption:@"新曲 · 最佳 15 首" y:y rows:3 coverDir:dir cols:5];

        // ---- 页脚 ----
        CGFloat fy = pageH - kMargin - kFooterH + 8;
        NSString *left = [NSString stringWithFormat:@"由 AstroDX B50 生成 · 定数来自 lxns 曲库 · 当前版本 %d", r.current];
        [left drawInRect:CGRectMake(kMargin, fy, 900, 18)
            withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:10.7],
                             NSForegroundColorAttributeName: RGB(130, 122, 158)}];
        NSString *right = [NSString stringWithFormat:@"未识别 %d 首不参与计算（自制谱 / 宴会场）", r.unmatched];
        [right drawInRect:CGRectMake(kPageW - kMargin - 620, fy, 620, 18)
            withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:10.7],
                             NSForegroundColorAttributeName: RGB(130, 122, 158),
                             NSParagraphStyleAttributeName: psRight}];
    }];
}

+ (CGFloat)drawSection:(ADXB50Result *)r list:(NSArray *)list sum:(int)sum index:(int)idx
                  name:(NSString *)name caption:(NSString *)caption y:(CGFloat)y rows:(int)rows
              coverDir:(NSString *)dir cols:(int)cols
{
    CGRect bar = CGRectMake(kMargin, y, kPageW - 2 * kMargin, 36);
    FillRound(bar, 14, RGB(0xF9, 0xD2, 0xE4), nil, 0);   // 玫瑰粉

    NSString *title = [NSString stringWithFormat:@"0%d.  %@", idx, name];
    UIFont *tf = [UIFont boldSystemFontOfSize:18.7];
    CGFloat th = [title sizeWithAttributes:@{NSFontAttributeName: tf}].height;
    [title drawInRect:CGRectMake(kMargin + 16, y + (36 - th) / 2, 400, th + 2)
        withAttributes:@{NSFontAttributeName: tf, NSForegroundColorAttributeName: RGB(0x7A, 0x30, 0x50)}];

    NSString *rightText = list.count
        ? [NSString stringWithFormat:@"%@ · 合计 %d · 平均 %d", caption, sum, sum / (int)list.count]
        : [NSString stringWithFormat:@"%@ · 没有可计入的谱面", caption];
    UIFont *rf = [UIFont systemFontOfSize:12.0];
    CGFloat rh = [rightText sizeWithAttributes:@{NSFontAttributeName: rf}].height;
    NSMutableParagraphStyle *psR = [NSMutableParagraphStyle new];
    psR.alignment = NSTextAlignmentRight;
    [rightText drawInRect:CGRectMake(kMargin, y + (36 - rh) / 2, kPageW - 2 * kMargin - 16, rh + 2)
        withAttributes:@{NSFontAttributeName: rf,
                         NSForegroundColorAttributeName: RGB(0x8A, 0x44, 0x62),
                         NSParagraphStyleAttributeName: psR}];

    // 起点固定按 7 列算，BEST 15 才会和 BEST 35 左边对齐（不会被居中）
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
    UIColor *base = DiffColor(e.diffId);
    BOOL light = IsLightCard(e.diffId);

    CGContextRef cg = UIGraphicsGetCurrentContext();
    // 必须保存/恢复图形状态：addClip 会一直生效，不恢复的话
    // 后面所有卡片、分段条、页脚都会被裁到第一张卡的范围里
    CGContextSaveGState(cg);

    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:card cornerRadius:10];
    [path addClip];

    // 渐变底
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[(id)Shade(base, 1.12).CGColor, (id)Shade(base, 0.80).CGColor];
    CGGradientRef grad = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, NULL);
    CGContextDrawLinearGradient(cg, grad, CGPointMake(card.origin.x, card.origin.y),
                                CGPointMake(card.origin.x, card.origin.y + card.size.height), 0);
    CGGradientRelease(grad);
    CGColorSpaceRelease(space);

    // 边框
    UIBezierPath *border = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(card, 0.7, 0.7) cornerRadius:10];
    border.lineWidth = 1.4;
    [Shade(base, 0.66) setStroke];
    [border stroke];

    UIColor *fg = light ? RGB(58, 46, 92) : [UIColor whiteColor];
    UIColor *muted = light ? RGB(120, 108, 150) : [UIColor colorWithWhite:1 alpha:0.78];

    // 曲绘
    CGRect coverRect = CGRectMake(card.origin.x + 8, card.origin.y + 8, 66, 66);
    UIBezierPath *clip = [UIBezierPath bezierPathWithRoundedRect:coverRect cornerRadius:6];
    UIImage *img = nil;
    if (e.songId > 0)
        img = [UIImage imageWithContentsOfFile:[self coverPath:dir songId:e.songId]];

    CGContextSaveGState(cg);
    [clip addClip];
    if (img) {
        CGFloat s = MAX(coverRect.size.width / img.size.width, coverRect.size.height / img.size.height);
        CGRect r = CGRectMake(coverRect.origin.x - (img.size.width * s - coverRect.size.width) / 2,
                              coverRect.origin.y - (img.size.height * s - coverRect.size.height) / 2,
                              img.size.width * s, img.size.height * s);
        [img drawInRect:r];
    } else {
        [RGB(52, 42, 80) setFill];
        UIRectFill(coverRect);
        NSString *ch = e.title.length ? [e.title substringToIndex:1] : @"?";
        UIFont *cf = [UIFont boldSystemFontOfSize:32.0];
        CGSize cs = [ch sizeWithAttributes:@{NSFontAttributeName: cf}];
        [ch drawAtPoint:CGPointMake(CGRectGetMidX(coverRect) - cs.width / 2,
                                    CGRectGetMidY(coverRect) - cs.height / 2)
         withAttributes:@{NSFontAttributeName: cf,
                          NSForegroundColorAttributeName: RGB(150, 140, 190)}];
    }
    CGContextRestoreGState(cg);

    // 排名角标
    FillRound(CGRectMake(card.origin.x + 8, card.origin.y + 59, 32, 15), 4,
              [UIColor colorWithWhite:0 alpha:0.66], nil, 0);
    [[NSString stringWithFormat:@"#%d", e.rank] drawAtPoint:CGPointMake(card.origin.x + 10, card.origin.y + 59.5)
        withAttributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:10.0],
                         NSForegroundColorAttributeName: [UIColor whiteColor]}];

    // 曲名
    CGFloat tw = kCardW - 88;
    UIFont *titleFont = [UIFont boldSystemFontOfSize:11.3];
    NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
    ps.lineBreakMode = NSLineBreakByTruncatingTail;
    NSDictionary *titleAttr = @{NSFontAttributeName: titleFont,
                                NSForegroundColorAttributeName: fg,
                                NSParagraphStyleAttributeName: ps};
    CGRect tbox = [e.title boundingRectWithSize:CGSizeMake(tw, 100)
                                        options:NSStringDrawingUsesLineFragmentOrigin
                                     attributes:titleAttr context:nil];
    if (tbox.size.height > titleFont.lineHeight * 2 + 1) {
        titleFont = [UIFont boldSystemFontOfSize:9.6];
        titleAttr = @{NSFontAttributeName: titleFont,
                      NSForegroundColorAttributeName: fg,
                      NSParagraphStyleAttributeName: ps};
    }
    [e.title drawInRect:CGRectMake(card.origin.x + 80, card.origin.y + 7, tw, 46)
         withAttributes:titleAttr];

    // 难度徽章 + 定数
    NSString *lvl = e.level.length ? e.level : @"?";
    UIFont *bf = [UIFont boldSystemFontOfSize:10.0];
    CGFloat bw = MAX(26, [lvl sizeWithAttributes:@{NSFontAttributeName: bf}].width + 8);
    FillRound(CGRectMake(card.origin.x + 8, card.origin.y + 82, bw, 17), 5,
              [UIColor colorWithWhite:0 alpha:0.82], nil, 0);
    [lvl drawAtPoint:CGPointMake(card.origin.x + 12, card.origin.y + 83)
      withAttributes:@{NSFontAttributeName: bf, NSForegroundColorAttributeName: [UIColor whiteColor]}];

    [[NSString stringWithFormat:@"%.1f", e.ds] drawAtPoint:CGPointMake(card.origin.x + 8 + bw + 6,
                                                                     card.origin.y + 84)
        withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:9.3],
                         NSForegroundColorAttributeName: muted}];

    // 达成率
    [[NSString stringWithFormat:@"%.4f%%", e.rate] drawAtPoint:CGPointMake(card.origin.x + 8,
                                                                         card.origin.y + 101)
        withAttributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:13.3],
                         NSForegroundColorAttributeName: fg}];

    // 单曲 Rating
    NSString *ra = [NSString stringWithFormat:@"%d", e.rating];
    UIFont *raf = [UIFont boldSystemFontOfSize:15.3];
    CGSize ras = [ra sizeWithAttributes:@{NSFontAttributeName: raf}];
    [ra drawAtPoint:CGPointMake(CGRectGetMaxX(card) - 8 - ras.width, card.origin.y + 98)
     withAttributes:@{NSFontAttributeName: raf,
                      NSForegroundColorAttributeName: light ? RGB(96, 56, 150) : [UIColor whiteColor]}];

    CGContextRestoreGState(cg);
}

+ (void)drawEmptyCard:(CGRect)card
{
    FillRound(card, 10, RGB(238, 234, 248), RGB(222, 214, 240), 1.2);
    NSString *dash = @"—";
    UIFont *f = [UIFont boldSystemFontOfSize:18.7];
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
