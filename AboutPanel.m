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
