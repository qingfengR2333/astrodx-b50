// AboutPanel.m
#import "AboutPanel.h"

// 图标以 base64 内嵌（dylib 没资源包）：120×120 / 64 色的 App 图标，48×48 的 GitHub 标
static NSString *const kAppIconBase64 = @"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";
static NSString *const kGitHubIconBase64 = @"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";

static NSString *const kAppName = @"AstroTools DX";
static NSString *const kVersion = @"v1.0.0";
static NSString *const kIntroTitle = @"工具介绍";
static NSString *const kIntroBody =
    @"AstroTools DX 是一款专为 AstroDX 玩家打造的辅助工具，支持 B50 成绩管理、"
    @"谱面导入、皮肤管理、资源管理等功能。通过简单的操作，帮助你更高效地管理游戏数据。";
static NSString *const kNoticeTitle = @"免责声明";
static NSString *const kNoticeBody =
    @"本工具为个人开发的非官方辅助工具，仅供学习交流使用。请遵守游戏规则和相关法律法规，"
    @"合理使用辅助工具，避免对游戏平衡造成不良影响。使用本工具所产生的任何后果，由用户自行承担。";

/// 手绘一个 bilibili 小电视（22×22），tint 后当图标用
static UIImage *ADXBiliIcon(void)
{
    UIGraphicsImageRendererFormat *f = [UIGraphicsImageRendererFormat defaultFormat];
    f.opaque = NO;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(22, 22) format:f];
    UIImage *img = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [[UIColor blackColor] setStroke];
        [[UIColor blackColor] setFill];

        UIBezierPath *a1 = [UIBezierPath bezierPath];
        [a1 moveToPoint:CGPointMake(7.5, 7)];
        [a1 addLineToPoint:CGPointMake(5, 3)];
        a1.lineWidth = 1.6;
        a1.lineCapStyle = kCGLineCapRound;
        [a1 stroke];

        UIBezierPath *a2 = [UIBezierPath bezierPath];
        [a2 moveToPoint:CGPointMake(14.5, 7)];
        [a2 addLineToPoint:CGPointMake(17, 3)];
        a2.lineWidth = 1.6;
        a2.lineCapStyle = kCGLineCapRound;
        [a2 stroke];

        UIBezierPath *tv = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2, 7, 18, 12) cornerRadius:3];
        tv.lineWidth = 1.6;
        [tv stroke];

        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(6.5, 11.5, 2, 2)] fill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(13.5, 11.5, 2, 2)] fill];
    }];
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@interface ADXAboutPanel ()
@end

@implementation ADXAboutPanel

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"关于";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor constant:20],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor constant:-20],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor constant:-28],
        [stack.widthAnchor constraintEqualToAnchor:scroll.widthAnchor constant:-40]
    ]];

    // 图标
    NSData *iconData = [[NSData alloc] initWithBase64EncodedString:kAppIconBase64 options:0];
    UIImage *icon = iconData ? [UIImage imageWithData:iconData] : nil;
    UIImageView *iconView = [[UIImageView alloc] initWithImage:icon];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconView.heightAnchor constraintEqualToConstant:99].active = YES;
    [iconView.widthAnchor constraintEqualToConstant:99].active = YES;

    UIStackView *iconRow = [[UIStackView alloc] initWithArrangedSubviews:@[iconView]];
    iconRow.axis = UILayoutConstraintAxisHorizontal;
    iconRow.alignment = UIStackViewAlignmentCenter;
    iconRow.distribution = UIStackViewDistributionEqualCentering;
    [stack addArrangedSubview:iconRow];

    UILabel *name = [[UILabel alloc] init];
    name.text = kAppName;
    name.font = [UIFont boldSystemFontOfSize:26];
    name.textAlignment = NSTextAlignmentCenter;
    [stack addArrangedSubview:name];

    [stack addArrangedSubview:[self spacer:14]];
    [stack addArrangedSubview:[self heading:kIntroTitle]];
    [stack addArrangedSubview:[self body:kIntroBody]];

    [stack addArrangedSubview:[self spacer:18]];
    [stack addArrangedSubview:[self heading:kNoticeTitle]];
    [stack addArrangedSubview:[self body:kNoticeBody]];

    [stack addArrangedSubview:[self spacer:24]];

    // 灰色小标题「开发者」，贴在卡片左上角上方
    UILabel *devLabel = [[UILabel alloc] init];
    devLabel.text = @"开发者";
    devLabel.font = [UIFont systemFontOfSize:12];
    devLabel.textColor = [UIColor secondaryLabelColor];
    UIStackView *devRow = [[UIStackView alloc] initWithArrangedSubviews:@[devLabel]];
    devRow.axis = UILayoutConstraintAxisHorizontal;
    devRow.alignment = UIStackViewAlignmentLeading;
    [stack addArrangedSubview:devRow];
    [stack setCustomSpacing:6 afterView:devRow];

    // 卡片
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor secondarySystemBackgroundColor];
    card.layer.cornerRadius = 12;
    card.clipsToBounds = YES;
    [stack addArrangedSubview:card];

    UIStackView *rows = [[UIStackView alloc] init];
    rows.axis = UILayoutConstraintAxisVertical;
    rows.spacing = 0;
    rows.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:rows];
    [NSLayoutConstraint activateConstraints:@[
        [rows.topAnchor constraintEqualToAnchor:card.topAnchor],
        [rows.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [rows.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [rows.bottomAnchor constraintEqualToAnchor:card.bottomAnchor]
    ]];

    [rows addArrangedSubview:[self cardRow:@"当前版本"
                                    detail:nil
                                 rightText:kVersion
                                 rightIcon:nil
                                       tag:0]];
    [rows addArrangedSubview:[self separator]];

    [rows addArrangedSubview:[self cardRow:@"关注作者"
                                    detail:@"谢谢关注 Zephyr 风白喵 awa"
                                 rightText:nil
                                 rightIcon:ADXBiliIcon()
                                       tag:1]];
    [rows addArrangedSubview:[self separator]];

    NSData *ghData = [[NSData alloc] initWithBase64EncodedString:kGitHubIconBase64 options:0];
    UIImage *gh = ghData
        ? [[UIImage imageWithData:ghData] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
        : nil;
    [rows addArrangedSubview:[self cardRow:@"关注 GitHub"
                                    detail:@"更多工具敬请期待"
                                 rightText:nil
                                 rightIcon:gh
                                       tag:2]];
}

- (UIView *)spacer:(CGFloat)h
{
    UIView *v = [[UIView alloc] init];
    [v.heightAnchor constraintEqualToConstant:h].active = YES;
    return v;
}

- (UILabel *)heading:(NSString *)text
{
    UILabel *l = [[UILabel alloc] init];
    l.text = text;
    l.font = [UIFont boldSystemFontOfSize:17];
    l.numberOfLines = 0;
    return l;
}

- (UILabel *)body:(NSString *)text
{
    UILabel *l = [[UILabel alloc] init];
    l.text = text;
    l.font = [UIFont systemFontOfSize:13];
    l.textColor = [UIColor labelColor];
    l.numberOfLines = 0;
    return l;
}

- (UIView *)separator
{
    UIView *wrap = [[UIView alloc] init];
    UIView *line = [[UIView alloc] init];
    line.backgroundColor = [UIColor separatorColor];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    [wrap addSubview:line];
    [NSLayoutConstraint activateConstraints:@[
        [wrap.heightAnchor constraintEqualToConstant:0.5],
        [line.topAnchor constraintEqualToAnchor:wrap.topAnchor],
        [line.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor],
        [line.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:16],
        [line.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor]
    ]];
    return wrap;
}

/// tag: 0 = 不可点；1 = B站；2 = GitHub
- (UIView *)cardRow:(NSString *)title
             detail:(NSString *)detail
          rightText:(NSString *)rightText
          rightIcon:(UIImage *)rightIcon
                tag:(NSInteger)tag
{
    BOOL hasDetail = detail.length > 0;

    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    b.tag = tag;
    if (tag != 0) [b addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];

    UILabel *t = [[UILabel alloc] init];
    t.text = title;
    t.font = [UIFont systemFontOfSize:16];
    t.textColor = [UIColor labelColor];

    UILabel *d = [[UILabel alloc] init];
    d.text = detail;
    d.font = [UIFont systemFontOfSize:12];
    d.textColor = [UIColor secondaryLabelColor];
    d.hidden = !hasDetail;

    UILabel *rt = [[UILabel alloc] init];
    rt.text = rightText;
    rt.font = [UIFont systemFontOfSize:15];
    rt.textColor = [UIColor secondaryLabelColor];
    rt.textAlignment = NSTextAlignmentRight;
    rt.hidden = (rightText.length == 0);

    UIImageView *ri = [[UIImageView alloc] initWithImage:rightIcon];
    ri.contentMode = UIViewContentModeScaleAspectFit;
    ri.tintColor = [UIColor secondaryLabelColor];
    ri.hidden = (rightIcon == nil);

    for (UIView *v in @[t, d, rt, ri]) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        v.userInteractionEnabled = NO;
        [b addSubview:v];
    }

    NSLayoutConstraint *titleCenter = [t.centerYAnchor constraintEqualToAnchor:b.centerYAnchor
                                                                       constant:hasDetail ? -9 : 0];

    [NSLayoutConstraint activateConstraints:@[
        [t.leadingAnchor constraintEqualToAnchor:b.leadingAnchor constant:16],
        [t.topAnchor constraintGreaterThanOrEqualToAnchor:b.topAnchor constant:6],
        titleCenter,

        [rt.trailingAnchor constraintEqualToAnchor:b.trailingAnchor constant:-16],
        [rt.centerYAnchor constraintEqualToAnchor:b.centerYAnchor],

        [ri.trailingAnchor constraintEqualToAnchor:b.trailingAnchor constant:-16],
        [ri.centerYAnchor constraintEqualToAnchor:b.centerYAnchor],
        [ri.widthAnchor constraintEqualToConstant:22],
        [ri.heightAnchor constraintEqualToConstant:22],

        [b.heightAnchor constraintGreaterThanOrEqualToConstant:hasDetail ? 64 : 48]
    ]];

    if (hasDetail) {
        [NSLayoutConstraint activateConstraints:@[
            [d.leadingAnchor constraintEqualToAnchor:t.leadingAnchor],
            [d.topAnchor constraintEqualToAnchor:t.bottomAnchor constant:2],
            [d.trailingAnchor constraintLessThanOrEqualToAnchor:b.trailingAnchor constant:-44],
            [d.bottomAnchor constraintLessThanOrEqualToAnchor:b.bottomAnchor constant:-10]
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [t.trailingAnchor constraintLessThanOrEqualToAnchor:rt.leadingAnchor constant:-8]
        ]];
    }

    return b;
}

- (void)rowTapped:(UIButton *)sender
{
    NSURL *url = nil;
    if (sender.tag == 1) url = [NSURL URLWithString:@"https://space.bilibili.com/604684222"];
    else if (sender.tag == 2) url = [NSURL URLWithString:@"https://github.com/qingfengR2333"];
    if (!url) return;

    UIApplication *app = [UIApplication sharedApplication];
    if ([app respondsToSelector:@selector(openURL:options:completionHandler:)])
        [app openURL:url options:@{} completionHandler:nil];
}

@end
