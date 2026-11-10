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
    [iconView.heightAnchor constraintEqualToConstant:110].active = YES;
    [iconView.widthAnchor constraintEqualToConstant:110].active = YES;

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
