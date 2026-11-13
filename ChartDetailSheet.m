// ChartDetailSheet.m — 「谱面详情」浮层：谱师 / 版本 + 物量表 + 判定占比
#import "ChartDetailSheet.h"
#import "ChartDb.h"
#import "B50Image.h"

static UIColor *SRGB(CGFloat r, CGFloat g, CGFloat b)
{
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}

static UIColor *SDiffColor(NSInteger d)
{
    switch (d) {
        case 0: return SRGB(66, 168, 92);
        case 1: return SRGB(232, 158, 44);
        case 2: return SRGB(214, 74, 88);
        case 3: return SRGB(150, 92, 214);
        case 4: return SRGB(196, 196, 208);
        default: return SRGB(150, 92, 214);
    }
}

/// 一行表格：名称、物量、四个判定
@interface ADXSheetRow : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *count;
@property (nonatomic, copy) NSArray *vals;
@end

@implementation ADXSheetRow
@end

@interface ADXChartSheet ()
@property (nonatomic, strong) UIView *dim;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIView *content;
@end

@implementation ADXChartSheet

#pragma mark - 弹出

+ (void)presentSong:(NSArray *)song
              chart:(NSArray *)chart
                 dx:(BOOL)dx
            version:(NSString *)version
           coverDir:(NSString *)coverDir
             inView:(UIView *)host
{
    if (!host || !song || !chart) return;

    CGFloat sw = MIN(560, host.bounds.size.width - 48);

    ADXChartSheet *sheet = [[ADXChartSheet alloc] initWithFrame:host.bounds];
    sheet.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    sheet.backgroundColor = [UIColor clearColor];

    UIView *dim = [[UIView alloc] initWithFrame:sheet.bounds];
    dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.38];
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [sheet addSubview:dim];
    sheet.dim = dim;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:sheet action:@selector(close)];
    [dim addGestureRecognizer:tap];

    [sheet buildWithSong:song chart:chart dx:dx version:version coverDir:coverDir width:sw];
    [host addSubview:sheet];

    sheet.alpha = 0;
    sheet.card.transform = CGAffineTransformMakeScale(0.94, 0.94);
    [UIView animateWithDuration:0.2
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        sheet.alpha = 1;
        sheet.card.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)close
{
    [UIView animateWithDuration:0.16
                     animations:^{
        self.alpha = 0;
        self.card.transform = CGAffineTransformMakeScale(0.96, 0.96);
    } completion:^(BOOL ok) {
        [self removeFromSuperview];
    }];
}

#pragma mark - 内容

- (void)buildWithSong:(NSArray *)song
                chart:(NSArray *)chart
                   dx:(BOOL)dx
              version:(NSString *)version
             coverDir:(NSString *)coverDir
                width:(CGFloat)SW
{
    self.content = [[UIView alloc] initWithFrame:CGRectMake(0, 0, SW, 0)];
    [self addSubview:self.content];

    NSInteger diff = [chart[0] integerValue];
    NSString *levelText = [ADXChartDb levelTextOfChart:chart];
    NSString *designer = [ADXChartDb designerOfChart:chart];

    CGFloat pad = 18;
    CGFloat inner = SW - pad * 2;
    CGFloat y = 18;

    // 曲绘
    CGFloat coverSide = 58;
    UIImageView *cover = [[UIImageView alloc] initWithFrame:CGRectMake(pad, y, coverSide, coverSide)];
    cover.backgroundColor = [UIColor tertiarySystemFillColor];
    cover.contentMode = UIViewContentModeScaleAspectFill;
    cover.layer.cornerRadius = 8;
    cover.layer.masksToBounds = YES;
    [self.content addSubview:cover];

    NSString *dir = coverDir.length ? coverDir
                   : [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/covers"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *img = [ADXImage coverImageFor:[song[0] intValue] dir:dir];
        if (!img) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            cover.image = img;
        });
    });

    CGFloat badgeW = 56;
    CGFloat tx = pad + coverSide + 12;
    CGFloat tw = inner - coverSide - 12 - badgeW - 12;

    UILabel *type = [[UILabel alloc] initWithFrame:CGRectMake(tx, y + 1, 32, 15)];
    type.text = dx ? @"DX" : @"标准";
    type.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightBold];
    type.textColor = [UIColor whiteColor];
    type.textAlignment = NSTextAlignmentCenter;
    type.backgroundColor = dx ? SRGB(214, 74, 88) : [UIColor systemBlueColor];
    type.layer.cornerRadius = 4;
    type.layer.masksToBounds = YES;
    [self.content addSubview:type];

    UILabel *no = [[UILabel alloc] initWithFrame:CGRectMake(tx + 38, y + 1, 110, 15)];
    no.text = [NSString stringWithFormat:@"No.%d", [ADXChartDb displayId:song]];
    no.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    no.textColor = [UIColor secondaryLabelColor];
    [self.content addSubview:no];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(tx, y + 19, tw, 22)];
    title.text = song[1];
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    title.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.content addSubview:title];

    UILabel *artist = [[UILabel alloc] initWithFrame:CGRectMake(tx, y + 41, tw, 15)];
    artist.text = song[2];
    artist.font = [UIFont systemFontOfSize:11.5];
    artist.textColor = [UIColor secondaryLabelColor];
    artist.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.content addSubview:artist];

    UIView *badge = [[UIView alloc] initWithFrame:CGRectMake(pad + inner - badgeW, y + 1, badgeW, badgeW)];
    badge.backgroundColor = SDiffColor(diff);
    badge.layer.cornerRadius = 10;
    badge.layer.masksToBounds = YES;
    [self.content addSubview:badge];

    UILabel *lv = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, badgeW, badgeW)];
    lv.text = levelText;
    lv.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    lv.textColor = (diff == 4) ? SRGB(52, 50, 66) : [UIColor whiteColor];
    lv.textAlignment = NSTextAlignmentCenter;
    [badge addSubview:lv];

    y += coverSide + 16;

    UIView *line1 = [[UIView alloc] initWithFrame:CGRectMake(pad, y, inner, 0.5)];
    line1.backgroundColor = [UIColor separatorColor];
    [self.content addSubview:line1];
    y += 14;

    UILabel *head = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, inner, 19)];
    head.text = @"谱面详情";
    head.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [self.content addSubview:head];
    y += 25;

    // 谱师 / 版本
    CGFloat colW = inner / 2.0;
    UILabel *dCap = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, colW, 14)];
    dCap.text = @"谱师";
    dCap.font = [UIFont systemFontOfSize:11];
    dCap.textColor = [UIColor secondaryLabelColor];
    [self.content addSubview:dCap];

    UILabel *vCap = [[UILabel alloc] initWithFrame:CGRectMake(pad + colW, y, colW, 14)];
    vCap.text = @"版本";
    vCap.font = [UIFont systemFontOfSize:11];
    vCap.textColor = [UIColor secondaryLabelColor];
    [self.content addSubview:vCap];

    UILabel *dVal = [[UILabel alloc] initWithFrame:CGRectMake(pad, y + 15, colW - 8, 18)];
    dVal.text = designer.length ? designer : @"-";
    dVal.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    dVal.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.content addSubview:dVal];

    UILabel *vVal = [[UILabel alloc] initWithFrame:CGRectMake(pad + colW, y + 15, colW - 8, 18)];
    vVal.text = version.length ? version : @"-";
    vVal.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [self.content addSubview:vVal];
    y += 42;

    // 表头
    NSArray *notes = [ADXChartDb notesOfChart:chart];
    NSArray *rows = [self rowsWithNotes:notes];

    CGFloat nameW = 96, countW = 62;
    CGFloat jw = (inner - nameW - countW) / 4.0;
    CGFloat rowH = 29;

    NSArray *heads = @[@"", @"物量", @"PERFECT", @"GREAT", @"GOOD", @"MISS"];
    NSArray *cols = @[[UIColor secondaryLabelColor],
                      [UIColor secondaryLabelColor],
                      SRGB(232, 152, 40),
                      SRGB(240, 92, 148),
                      SRGB(56, 176, 104),
                      [UIColor labelColor]];

    UIView *line2 = [[UIView alloc] initWithFrame:CGRectMake(pad, y, inner, 0.5)];
    line2.backgroundColor = [UIColor separatorColor];
    [self.content addSubview:line2];
    y += 7;

    for (int i = 0; i < 6; i++) {
        CGFloat cx = pad;
        CGFloat cw = nameW;
        if (i == 1) { cx = pad + nameW; cw = countW; }
        if (i >= 2) { cx = pad + nameW + countW + jw * (i - 2); cw = jw; }

        UILabel *h = [[UILabel alloc] initWithFrame:CGRectMake(cx, y, cw, 15)];
        h.text = heads[i];
        h.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold];
        h.textColor = cols[i];
        [self.content addSubview:h];
    }
    y += 21;

    UIView *line3 = [[UIView alloc] initWithFrame:CGRectMake(pad, y, inner, 0.5)];
    line3.backgroundColor = [UIColor separatorColor];
    [self.content addSubview:line3];
    y += 5;

    for (ADXSheetRow *r in rows) {
        UILabel *n = [[UILabel alloc] initWithFrame:CGRectMake(pad, y + 5, nameW, 17)];
        n.text = r.name;
        n.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
        [self.content addSubview:n];

        UILabel *c = [[UILabel alloc] initWithFrame:CGRectMake(pad + nameW, y + 5, countW, 17)];
        c.text = r.count;
        c.font = [UIFont systemFontOfSize:12.5];
        c.textColor = [UIColor secondaryLabelColor];
        [self.content addSubview:c];

        for (int i = 0; i < 4; i++) {
            UILabel *v = [[UILabel alloc] initWithFrame:CGRectMake(pad + nameW + countW + jw * i, y + 5, jw, 17)];
            v.text = r.vals[i];
            v.font = [UIFont systemFontOfSize:12];
            v.textColor = [UIColor secondaryLabelColor];
            [self.content addSubview:v];
        }

        UIView *ln = [[UIView alloc] initWithFrame:CGRectMake(pad, y + rowH - 0.5, inner, 0.5)];
        ln.backgroundColor = [[UIColor separatorColor] colorWithAlphaComponent:0.55];
        [self.content addSubview:ln];

        y += rowH;
    }

    y += 8;

    UILabel *foot = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, inner, 30)];
    foot.text = @"※ 该表格代表每个 Note 不同判定在达成率中所占的比例，结果仅供参考。";
    foot.font = [UIFont systemFontOfSize:10.5];
    foot.textColor = [UIColor tertiaryLabelColor];
    foot.numberOfLines = 2;
    [self.content addSubview:foot];
    y += 34;

    // 卡片定位
    self.content.frame = CGRectMake(0, 0, SW, y);
    self.content.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.content.layer.cornerRadius = 16;
    self.content.layer.masksToBounds = YES;
    self.content.frame = CGRectMake(round((self.bounds.size.width - SW) / 2),
                                    round((self.bounds.size.height - y) / 2),
                                    SW, y);
    self.card = self.content;
}

#pragma mark - 计算

/// 权重：TAP 1、HOLD 2、SLIDE 3、TOUCH 1、BREAK 5
/// 单音符损失：PERFECT 0、GREAT 20%、GOOD 50%、MISS 100%
- (NSArray *)rowsWithNotes:(NSArray *)notes
{
    static NSArray *names = nil;
    static NSArray *weights = nil;
    if (!names) {
        names = @[@"TAP", @"HOLD", @"SLIDE", @"TOUCH", @"BREAK"];
        weights = @[@1, @2, @3, @1, @5];
    }

    NSMutableArray *rows = [NSMutableArray array];

    if (!notes || notes.count != 5) {
        ADXSheetRow *r = [[ADXSheetRow alloc] init];
        r.name = @"TOTAL";
        r.count = @"-";
        r.vals = @[@"-", @"-", @"-", @"-"];
        [rows addObject:r];
        return rows;
    }

    int counts[5] = {0, 0, 0, 0, 0};
    double total = 0;
    int sum = 0;
    for (int i = 0; i < 5; i++) {
        counts[i] = [notes[i] intValue];
        sum += counts[i];
        total += counts[i] * [weights[i] doubleValue];
    }

    ADXSheetRow *top = [[ADXSheetRow alloc] init];
    top.name = @"TOTAL";
    top.count = [NSString stringWithFormat:@"%d", sum];
    top.vals = @[@"-", @"-", @"-", @"-"];
    [rows addObject:top];

    if (total <= 0) return rows;

    for (int i = 0; i < 5; i++) {
        if (i == 3 && counts[i] == 0) continue;      // 标准谱面没有 TOUCH

        double unit = 100.0 * [weights[i] doubleValue] / total;

        ADXSheetRow *r = [[ADXSheetRow alloc] init];
        r.name = names[i];
        r.count = [NSString stringWithFormat:@"%d", counts[i]];
        r.vals = @[[NSString stringWithFormat:@"%.4f%%", 0.0],
                   [NSString stringWithFormat:@"-%.4f%%", unit * 0.2],
                   [NSString stringWithFormat:@"-%.4f%%", unit * 0.5],
                   [NSString stringWithFormat:@"-%.4f%%", unit]];
        [rows addObject:r];
    }

    return rows;
}

@end
