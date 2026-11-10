// AboutPanel.m
#import "AboutPanel.h"

// 120×120、64 色的 PNG（base64），运行时解出来当图标
static NSString *const kIconBase64 = @"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";

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

@interface ADXAboutPanel ()
@end

@implementation ADXAboutPanel

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"关于";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // 右上角小字“开发者”
    UILabel *dev = [[UILabel alloc] init];
    dev.text = @"开发者";
    dev.font = [UIFont systemFontOfSize:11];
    dev.textColor = [UIColor secondaryLabelColor];
    [dev sizeToFit];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:dev];

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
        [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor constant:-24],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor constant:-28],
        [stack.widthAnchor constraintEqualToAnchor:scroll.widthAnchor constant:-48]
    ]];

    // 图标
    NSData *iconData = [[NSData alloc] initWithBase64EncodedString:kIconBase64 options:0];
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

    // 工具名
    UILabel *name = [[UILabel alloc] init];
    name.text = kAppName;
    name.font = [UIFont boldSystemFontOfSize:26];
    name.textAlignment = NSTextAlignmentCenter;
    [stack addArrangedSubview:name];

    [stack addArrangedSubview:[self spacer:14]];

    // 工具介绍
    [stack addArrangedSubview:[self heading:kIntroTitle]];
    [stack addArrangedSubview:[self body:kIntroBody]];

    [stack addArrangedSubview:[self spacer:18]];

    // 免责声明
    [stack addArrangedSubview:[self heading:kNoticeTitle]];
    [stack addArrangedSubview:[self body:kNoticeBody]];

    [stack addArrangedSubview:[self spacer:22]];

    // 信息行
    [stack addArrangedSubview:[self rowTitle:@"当前版本" subtitle:kVersion tag:0]];
    [stack addArrangedSubview:[self separator]];
    [stack addArrangedSubview:[self rowTitle:@"关注作者" subtitle:@"谢谢关注 Zephyr 风白喵 awa" tag:1]];
    [stack addArrangedSubview:[self separator]];
    [stack addArrangedSubview:[self rowTitle:@"关注 Github" subtitle:@"更多工具敬请期待" tag:2]];
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
    UIView *v = [[UIView alloc] init];
    v.backgroundColor = [UIColor separatorColor];
    [v.heightAnchor constraintEqualToConstant:0.5].active = YES;
    return v;
}

/// tag: 0 = 不可点；1 = B站；2 = GitHub
- (UIView *)rowTitle:(NSString *)title subtitle:(NSString *)subtitle tag:(NSInteger)tag
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.tag = tag;
    if (tag != 0) [b addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];

    UILabel *t = [[UILabel alloc] init];
    t.text = title;
    t.font = [UIFont systemFontOfSize:15];
    t.textColor = (tag == 0) ? [UIColor labelColor] : [UIColor systemBlueColor];

    UILabel *s = [[UILabel alloc] init];
    s.text = subtitle;
    s.font = [UIFont systemFontOfSize:12];
    s.textColor = [UIColor secondaryLabelColor];

    UIImageView *chev = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    chev.tintColor = [UIColor tertiaryLabelColor];
    chev.contentMode = UIViewContentModeScaleAspectFit;
    chev.hidden = (tag == 0);

    for (UIView *v in @[t, s, chev]) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [b addSubview:v];
    }
    [NSLayoutConstraint activateConstraints:@[
        [t.leadingAnchor constraintEqualToAnchor:b.leadingAnchor],
        [t.topAnchor constraintEqualToAnchor:b.topAnchor constant:10],
        [s.leadingAnchor constraintEqualToAnchor:t.leadingAnchor],
        [s.topAnchor constraintEqualToAnchor:t.bottomAnchor constant:2],
        [s.bottomAnchor constraintEqualToAnchor:b.bottomAnchor constant:-10],
        [s.trailingAnchor constraintLessThanOrEqualToAnchor:chev.leadingAnchor constant:-8],

        [chev.centerYAnchor constraintEqualToAnchor:b.centerYAnchor],
        [chev.trailingAnchor constraintEqualToAnchor:b.trailingAnchor],
        [chev.widthAnchor constraintEqualToConstant:12],
        [chev.heightAnchor constraintEqualToConstant:16]
    ]];
    return b;
}

- (void)rowTapped:(UIButton *)sender
{
    NSURL *url = nil;
    if (sender.tag == 1) {
        url = [NSURL URLWithString:@"https://space.bilibili.com/604684222"];
    } else if (sender.tag == 2) {
        url = [NSURL URLWithString:@"https://github.com/qingfengR2333"];
    }
    if (!url) return;

    UIApplication *app = [UIApplication sharedApplication];
    if ([app respondsToSelector:@selector(openURL:options:completionHandler:)]) {
        [app openURL:url options:@{} completionHandler:nil];
    }
}

@end
