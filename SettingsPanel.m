// SettingsPanel.m
#import "SettingsPanel.h"
#import "B50Image.h"
#import "ChartDb.h"
#import <math.h>

NSString *const ADXSettingsChangedNotification = @"ADXSettingsChanged";

static NSString *const kTriggerKey = @"adx.trigger";
static NSString *const kColorKey   = @"adx.color";
static NSString *const kAlphaKey   = @"adx.alpha";
static NSString *const kTextKey    = @"adx.text";
static NSString *const kSizeKey    = @"adx.size";
static NSString *const kTextAlphaKey = @"adx.textAlpha";
static NSString *const kShowScoresKey = @"adx.showScores";
static NSString *const kShowB50Key    = @"adx.showB50";
static NSString *const kShowImageKey  = @"adx.showImage";
static NSString *const kShowBrowseKey = @"adx.showBrowse";

static NSString *HexFromColor(UIColor *c)
{
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![c getRed:&r green:&g blue:&b alpha:&a]) return @"#4385F7";
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)lround(r * 255), (int)lround(g * 255), (int)lround(b * 255)];
}

static UIImageSymbolConfiguration *ADXChevronConfig(void)
{
    return [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIFontWeightSemibold];
}

static UIColor *ColorFromHex(NSString *hex)
{
    if (hex.length < 7) return [UIColor colorWithRed:0x43/255.0 green:0x85/255.0 blue:0xF7/255.0 alpha:1];
    unsigned int v = 0;
    NSScanner *sc = [NSScanner scannerWithString:[hex substringFromIndex:1]];
    [sc scanHexInt:&v];
    return [UIColor colorWithRed:((v >> 16) & 0xFF) / 255.0
                           green:((v >> 8) & 0xFF) / 255.0
                            blue:(v & 0xFF) / 255.0
                           alpha:1.0];
}

@implementation ADXSettings

+ (NSUserDefaults *)d { return [NSUserDefaults standardUserDefaults]; }

+ (NSInteger)trigger
{
    id v = [[self d] objectForKey:kTriggerKey];
    return v ? [[self d] integerForKey:kTriggerKey] : 1;      // 默认双击
}

+ (UIColor *)color
{
    NSString *hex = [[self d] stringForKey:kColorKey];
    return ColorFromHex(hex.length ? hex : @"#F5F5F5");     // 默认白色
}

+ (CGFloat)alpha
{
    id v = [[self d] objectForKey:kAlphaKey];
    return v ? [[self d] doubleForKey:kAlphaKey] : 0.15;
}

+ (NSString *)text
{
    NSString *t = [[self d] stringForKey:kTextKey];
    return t.length ? t : @"Tools";
}

+ (CGFloat)size
{
    id v = [[self d] objectForKey:kSizeKey];
    CGFloat s = v ? [[self d] doubleForKey:kSizeKey] : 50;
    return MIN(96, MAX(40, s));
}

+ (CGFloat)textAlpha
{
    id v = [[self d] objectForKey:kTextAlphaKey];
    CGFloat a = v ? [[self d] doubleForKey:kTextAlphaKey] : 0.70;
    return MIN(1.0, MAX(0.0, a));
}

+ (BOOL)showScoresButton
{
    id v = [[self d] objectForKey:kShowScoresKey];
    return v ? [[self d] boolForKey:kShowScoresKey] : NO;     // 默认关闭
}

+ (BOOL)showB50Button
{
    id v = [[self d] objectForKey:kShowB50Key];
    return v ? [[self d] boolForKey:kShowB50Key] : NO;        // 默认关闭
}

+ (BOOL)showImageButton
{
    id v = [[self d] objectForKey:kShowImageKey];
    return v ? [[self d] boolForKey:kShowImageKey] : YES;
}

+ (BOOL)showBrowsePage
{
    id v = [[self d] objectForKey:kShowBrowseKey];
    return v ? [[self d] boolForKey:kShowBrowseKey] : YES;
}

@end

#pragma mark - 面板

@interface ADXSettingsPanel () <UITextFieldDelegate, UIScrollViewDelegate>
@property (nonatomic, strong) UISlider *alphaSlider;
@property (nonatomic, strong) UISlider *textAlphaSlider;
@property (nonatomic, strong) UITextField *textAlphaField;
@property (nonatomic, strong) UISlider *sizeSlider;
@property (nonatomic, strong) UITextField *alphaField;
@property (nonatomic, strong) UITextField *sizeField;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UISegmentedControl *triggerSeg;
@property (nonatomic, strong) NSMutableArray<UIButton *> *swatches;

// 折叠状态
@property (nonatomic, strong) NSMutableArray *ballViews;
@property (nonatomic, strong) NSMutableArray *funcViews;
@property (nonatomic, strong) NSMutableArray *colorViews;
@property (nonatomic, strong) UIView *ballHeader;
@property (nonatomic, strong) UIView *funcHeader;
@property (nonatomic, strong) UIImageView *ballChevron;
@property (nonatomic, strong) UIImageView *funcChevron;
@property (nonatomic, strong) UIImageView *colorChevron;
@property (nonatomic, strong) UILabel *sticky;
@property (nonatomic, strong) UILabel *preloadLabel;
@property (nonatomic, assign) BOOL preloading;

- (UIViewController *)topPresenter;
- (void)askFinalConfirm;
@property (nonatomic, strong) UIButton *preloadButton;
@property (nonatomic, strong) UIButton *clearCoversButton;
@property (nonatomic, strong) UIProgressView *preloadProgress;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, assign) BOOL ballOpen;
@property (nonatomic, assign) BOOL funcOpen;
@property (nonatomic, assign) BOOL colorOpen;

- (UIStackView *)sliderRowForAlpha:(BOOL)isAlpha unit:(NSString *)unit;
- (UIStackView *)sliderRowForTextAlpha:(NSString *)unit;
- (UILabel *)bigTitle:(NSString *)text;
- (UIStackView *)switchRow:(NSString *)title on:(BOOL)on action:(SEL)action;
- (UILabel *)sectionTitle:(NSString *)text;
- (UILabel *)hint:(NSString *)text;
- (UIView *)spacer:(CGFloat)h;
- (void)applyAlpha:(CGFloat)pct;
- (void)applySize:(CGFloat)v;
- (void)refreshSwatches;
- (UIView *)sectionHeader:(NSString *)title ball:(BOOL)ball;
- (void)applyCollapse;
@end

// 导入模块用的钢蓝配色，曲绘缓存按钮沿用
static NSString *ADXSizeText(unsigned long long bytes)
{
    if (bytes == 0) return @"0 MB";
    double mb = (double)bytes / 1024.0 / 1024.0;
    if (mb < 1.0) return [NSString stringWithFormat:@"%.0f KB", (double)bytes / 1024.0];
    if (mb < 100.0) return [NSString stringWithFormat:@"%.1f MB", mb];
    return [NSString stringWithFormat:@"%.0f MB", mb];
}

static UIColor *ADXSteel(void)
{
    return [UIColor colorWithRed:0x91 / 255.0 green:0xB1 / 255.0 blue:0xD0 / 255.0 alpha:1.0];
}

static UIColor *ADXSteelInk(void)
{
    return [UIColor colorWithRed:0x20 / 255.0 green:0x36 / 255.0 blue:0x4F / 255.0 alpha:1.0];
}

static UIColor *ADXCRed(void)
{
    return [UIColor colorWithRed:0xB4 / 255.0 green:0x53 / 255.0 blue:0x4B / 255.0 alpha:1.0];
}

@implementation ADXSettingsPanel

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"设置";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    scroll.delegate = self;
    [self.view addSubview:scroll];
    self.scroll = scroll;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];
    self.stack = stack;

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor constant:16],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor constant:-16],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor constant:-24],
        [stack.widthAnchor constraintEqualToAnchor:scroll.widthAnchor constant:-32]
    ]];

    // 滚动时的板块指示条
    self.sticky = [[UILabel alloc] init];
    self.sticky.translatesAutoresizingMaskIntoConstraints = NO;
    self.sticky.font = [UIFont boldSystemFontOfSize:13];
    self.sticky.textColor = [UIColor secondaryLabelColor];
    self.sticky.backgroundColor = [UIColor systemBackgroundColor];
    self.sticky.alpha = 0;
    self.sticky.userInteractionEnabled = NO;
    [self.view addSubview:self.sticky];
    [NSLayoutConstraint activateConstraints:@[
        [self.sticky.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.sticky.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18],
        [self.sticky.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18],
        [self.sticky.heightAnchor constraintEqualToConstant:22]
    ]];

    self.ballHeader = [self sectionHeader:@"悬浮球" ball:YES];
    [stack addArrangedSubview:self.ballHeader];
    UIView *ballGap = [self spacer:4];
    [stack addArrangedSubview:ballGap];
    NSUInteger ballStart = stack.arrangedSubviews.count;

    // 1. 触发方式
    [stack addArrangedSubview:[self sectionTitle:@"触发方式"]];
    self.triggerSeg = [[UISegmentedControl alloc] initWithItems:@[@"单击", @"双击", @"长按"]];
    self.triggerSeg.selectedSegmentIndex = [ADXSettings trigger];
    [self.triggerSeg addTarget:self action:@selector(triggerChanged) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:self.triggerSeg];
    [stack addArrangedSubview:[self hint:@"只能选一个，用来替代原来的固定双击"]];

    [stack addArrangedSubview:[self spacer:10]];

    // 2. 颜色（默认折叠，防误触）
    UIView *colorRow = [[UIView alloc] init];
    [colorRow.heightAnchor constraintEqualToConstant:30].active = YES;

    UILabel *colorLabel = [[UILabel alloc] init];
    colorLabel.text = @"颜色";
    colorLabel.font = [UIFont boldSystemFontOfSize:15];
    colorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [colorRow addSubview:colorLabel];

    UIImageSymbolConfiguration *chevCfg =
        [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIFontWeightSemibold];
    UIImageView *colorArrow = [[UIImageView alloc] initWithImage:
                               [UIImage systemImageNamed:@"chevron.right" withConfiguration:chevCfg]];
    colorArrow.contentMode = UIViewContentModeCenter;
    colorArrow.tintColor = [UIColor tertiaryLabelColor];
    colorArrow.contentMode = UIViewContentModeCenter;
    colorArrow.translatesAutoresizingMaskIntoConstraints = NO;
    [colorRow addSubview:colorArrow];
    self.colorChevron = colorArrow;

    [NSLayoutConstraint activateConstraints:@[
        [colorLabel.leadingAnchor constraintEqualToAnchor:colorRow.leadingAnchor],
        [colorLabel.centerYAnchor constraintEqualToAnchor:colorRow.centerYAnchor],
        [colorArrow.trailingAnchor constraintEqualToAnchor:colorRow.trailingAnchor constant:-16],
        [colorArrow.centerYAnchor constraintEqualToAnchor:colorRow.centerYAnchor]
    ]];

    [colorRow addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(toggleColor)]];
    [stack addArrangedSubview:colorRow];
    NSUInteger colorStart = stack.arrangedSubviews.count;
    self.swatches = [NSMutableArray array];
    NSArray *palette = @[
        @"#4385F7", @"#4FC3F7", @"#26C6DA", @"#26A69A", @"#66BB6A",
        @"#9CCC65", @"#FFEE58", @"#FFCA28", @"#FFA726", @"#FF7043",
        @"#EF5350", @"#EC407A", @"#AB47BC", @"#7E57C2", @"#5C6BC0",
        @"#8D6E63", @"#9E9E9E", @"#607D8B", @"#212121", @"#F5F5F5"
    ];
    UIStackView *row = nil;
    for (NSUInteger i = 0; i < palette.count; i++) {
        if (i % 5 == 0) {
            row = [[UIStackView alloc] init];
            row.axis = UILayoutConstraintAxisHorizontal;
            row.spacing = 10;
            row.distribution = UIStackViewDistributionFillEqually;
            [stack addArrangedSubview:row];
        }
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.backgroundColor = ColorFromHex(palette[i]);
        b.layer.cornerRadius = 8;
        b.tag = (NSInteger)i;
        [b.heightAnchor constraintEqualToConstant:40].active = YES;
        [b addTarget:self action:@selector(colorTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.swatches addObject:b];
        [row addArrangedSubview:b];
    }
    [self refreshSwatches];

    NSUInteger colorEnd = stack.arrangedSubviews.count;
    self.colorViews = [[stack.arrangedSubviews
                        subarrayWithRange:NSMakeRange(colorStart, colorEnd - colorStart)] mutableCopy];

    [stack addArrangedSubview:[self spacer:10]];

    // 3. 背景透明度
    [stack addArrangedSubview:[self sectionTitle:@"背景透明度"]];
    UIStackView *alphaRow = [self sliderRowForAlpha:YES unit:@"%"];
    [self.alphaSlider addTarget:self action:@selector(alphaSliderChanged) forControlEvents:UIControlEventValueChanged];
    [self.alphaField addTarget:self action:@selector(alphaFieldChanged) forControlEvents:UIControlEventEditingDidEnd];
    [stack addArrangedSubview:alphaRow];
    self.alphaSlider.minimumValue = 5;
    self.alphaSlider.maximumValue = 100;
    self.alphaSlider.value = [ADXSettings alpha] * 100;
    self.alphaField.text = [NSString stringWithFormat:@"%d", (int)lround([ADXSettings alpha] * 100)];

    // 3b. 字体透明度
    [stack addArrangedSubview:[self spacer:6]];
    [stack addArrangedSubview:[self sectionTitle:@"字体透明度"]];
    UIStackView *textAlphaRow = [self sliderRowForTextAlpha:@"%"];
    [stack addArrangedSubview:textAlphaRow];
    self.textAlphaSlider.minimumValue = 0;
    self.textAlphaSlider.maximumValue = 100;
    self.textAlphaSlider.value = [ADXSettings textAlpha] * 100;
    self.textAlphaField.text = [NSString stringWithFormat:@"%d", (int)lround([ADXSettings textAlpha] * 100)];

    [stack addArrangedSubview:[self spacer:10]];

    // 4. 文字
    [stack addArrangedSubview:[self sectionTitle:@"悬浮球文字"]];
    self.textField = [[UITextField alloc] init];
    self.textField.borderStyle = UITextBorderStyleRoundedRect;
    self.textField.text = [ADXSettings text];
    self.textField.placeholder = @"ADX";
    self.textField.returnKeyType = UIReturnKeyDone;
    self.textField.delegate = self;
    [self.textField addTarget:self action:@selector(textChanged) forControlEvents:UIControlEventEditingDidEnd];
    [self.textField.heightAnchor constraintEqualToConstant:36].active = YES;
    [stack addArrangedSubview:self.textField];
    [stack addArrangedSubview:[self hint:@"字号会自动缩放，保证不超出球的范围"]];

    [stack addArrangedSubview:[self spacer:10]];

    // 5. 大小
    [stack addArrangedSubview:[self sectionTitle:@"悬浮球大小"]];
    UIStackView *sizeRow = [self sliderRowForAlpha:NO unit:@"pt"];
    [self.sizeSlider addTarget:self action:@selector(sizeSliderChanged) forControlEvents:UIControlEventValueChanged];
    [self.sizeField addTarget:self action:@selector(sizeFieldChanged) forControlEvents:UIControlEventEditingDidEnd];
    [stack addArrangedSubview:sizeRow];
    self.sizeSlider.minimumValue = 40;
    self.sizeSlider.maximumValue = 96;
    self.sizeSlider.value = [ADXSettings size];
    self.sizeField.text = [NSString stringWithFormat:@"%d", (int)lround([ADXSettings size])];
    [stack addArrangedSubview:[self hint:@"范围 40～96 pt"]];

    // 悬浮球板块内容（颜色卡单独一组，不重复计入）
    NSUInteger ballEnd = stack.arrangedSubviews.count;
    NSMutableArray *ballAll = [[stack.arrangedSubviews
                                subarrayWithRange:NSMakeRange(ballStart, ballEnd - ballStart)] mutableCopy];
    [ballAll removeObjectsInArray:self.colorViews];
    [ballAll addObject:ballGap];          // 收起时连标题下方的留白一起收，板块间距缩到约 2/3
    self.ballViews = ballAll;

    // 板块之间：分割线 + 更紧的留白（收起时也不会显得空）
    UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 0.5)];
    divider.backgroundColor = [UIColor separatorColor];
    [stack addArrangedSubview:divider];
    [stack addArrangedSubview:[self spacer:8]];

    self.funcHeader = [self sectionHeader:@"功能" ball:NO];
    [stack addArrangedSubview:self.funcHeader];
    [stack addArrangedSubview:[self spacer:4]];
    NSUInteger funcStart = stack.arrangedSubviews.count;
    [stack addArrangedSubview:[self switchRow:@"首页显示「导出分表」按钮"
                                          on:[ADXSettings showScoresButton]
                                      action:@selector(toggleScores:)]];
    [stack addArrangedSubview:[self switchRow:@"首页显示「导出 b50 表」按钮"
                                          on:[ADXSettings showB50Button]
                                      action:@selector(toggleB50:)]];
    [stack addArrangedSubview:[self switchRow:@"首页显示「导出 b50 成绩图」按钮"
                                          on:[ADXSettings showImageButton]
                                      action:@selector(toggleImage:)]];
    [stack addArrangedSubview:[self switchRow:@"谱面查询显示分类浏览页"
                                          on:[ADXSettings showBrowsePage]
                                      action:@selector(toggleBrowse:)]];
    // 曲绘缓存：一次性按钮 + 进度条 + 删除缓存（同一行并排）
    UIStackView *coverRow = [[UIStackView alloc] initWithFrame:CGRectZero];
    coverRow.axis = UILayoutConstraintAxisHorizontal;
    coverRow.spacing = 10;
    coverRow.distribution = UIStackViewDistributionFillEqually;
    coverRow.alignment = UIStackViewAlignmentFill;
    coverRow.translatesAutoresizingMaskIntoConstraints = NO;
    [coverRow.heightAnchor constraintEqualToConstant:42].active = YES;

    self.preloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.preloadButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.preloadButton.layer.cornerRadius = 10;
    self.preloadButton.layer.masksToBounds = YES;
    [self.preloadButton addTarget:self action:@selector(preloadTapped)
                 forControlEvents:UIControlEventTouchUpInside];
    [coverRow addArrangedSubview:self.preloadButton];

    self.clearCoversButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clearCoversButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.clearCoversButton.layer.cornerRadius = 10;
    self.clearCoversButton.layer.borderWidth = 0.5;
    self.clearCoversButton.layer.borderColor = ADXCRed().CGColor;
    self.clearCoversButton.backgroundColor = [UIColor clearColor];
    [self.clearCoversButton setTitle:@"删除曲绘缓存" forState:UIControlStateNormal];
    [self.clearCoversButton setTitleColor:ADXCRed() forState:UIControlStateNormal];
    [self.clearCoversButton addTarget:self action:@selector(clearCoversTapped)
                     forControlEvents:UIControlEventTouchUpInside];
    [coverRow addArrangedSubview:self.clearCoversButton];

    [stack addArrangedSubview:coverRow];

    self.preloadProgress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.preloadProgress.hidden = YES;
    [stack addArrangedSubview:self.preloadProgress];

    UILabel *pl = [[UILabel alloc] initWithFrame:CGRectZero];
    pl.numberOfLines = 0;
    pl.font = [UIFont systemFontOfSize:12];
    pl.textColor = [UIColor secondaryLabelColor];
    pl.text = @"把全部曲绘缓存到本地（约 150–200 MB，Wi-Fi 下大约 10–20 分钟），之后浏览就不会再出现灰块。";
    self.preloadLabel = pl;
    [stack addArrangedSubview:pl];

    [self refreshCoverCacheUI];

    NSUInteger funcEnd = stack.arrangedSubviews.count;
    self.funcViews = [[stack.arrangedSubviews
                       subarrayWithRange:NSMakeRange(funcStart, funcEnd - funcStart)] mutableCopy];

    // 默认：两个板块展开，颜色卡折叠
    self.ballOpen = YES;
    self.funcOpen = YES;
    self.colorOpen = NO;
    [self applyCollapse];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(endEditing)];
    tap.cancelsTouchesInView = NO;
    [scroll addGestureRecognizer:tap];
}

- (void)endEditing { [self.view endEditing:YES]; }

- (UILabel *)sectionTitle:(NSString *)text
{
    UILabel *l = [[UILabel alloc] init];
    l.text = text;
    l.font = [UIFont boldSystemFontOfSize:15];
    return l;
}

- (UILabel *)hint:(NSString *)text
{
    UILabel *l = [[UILabel alloc] init];
    l.text = text;
    l.numberOfLines = 0;
    l.font = [UIFont systemFontOfSize:12];
    l.textColor = [UIColor secondaryLabelColor];
    return l;
}

- (UIView *)spacer:(CGFloat)h
{
    UIView *v = [[UIView alloc] init];
    [v.heightAnchor constraintEqualToConstant:h].active = YES;
    return v;
}

- (UIStackView *)sliderRowForAlpha:(BOOL)isAlpha unit:(NSString *)unit
{
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 10;
    row.alignment = UIStackViewAlignmentCenter;

    UISlider *slider = [[UISlider alloc] init];

    UITextField *field = [[UITextField alloc] init];
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.textAlignment = NSTextAlignmentCenter;
    field.keyboardType = UIKeyboardTypeNumberPad;
    field.delegate = self;
    [field.widthAnchor constraintEqualToConstant:64].active = YES;
    [field.heightAnchor constraintEqualToConstant:36].active = YES;

    UILabel *unitLabel = [[UILabel alloc] init];
    unitLabel.text = unit;
    unitLabel.font = [UIFont systemFontOfSize:12];
    unitLabel.textColor = [UIColor secondaryLabelColor];

    [row addArrangedSubview:slider];
    [row addArrangedSubview:field];
    [row addArrangedSubview:unitLabel];

    // 直接存进属性，避免对 ivar 取地址（ARC 不允许）
    if (isAlpha) {
        self.alphaSlider = slider;
        self.alphaField = field;
    } else {
        self.sizeSlider = slider;
        self.sizeField = field;
    }
    return row;
}

- (UILabel *)bigTitle:(NSString *)text
{
    UILabel *l = [[UILabel alloc] init];
    l.text = text;
    l.font = [UIFont boldSystemFontOfSize:22];
    return l;
}

#pragma mark - 板块标题 / 折叠

- (UIView *)sectionHeader:(NSString *)title ball:(BOOL)ball
{
    UIView *box = [[UIView alloc] init];
    box.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    box.layer.cornerRadius = 12;
    [box.heightAnchor constraintEqualToConstant:52].active = YES;

    UIView *accent = [[UIView alloc] init];
    accent.translatesAutoresizingMaskIntoConstraints = NO;
    accent.backgroundColor = [UIColor systemBlueColor];
    accent.layer.cornerRadius = 2;
    [box addSubview:accent];

    UILabel *l = [[UILabel alloc] init];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    l.text = title;
    l.font = [UIFont boldSystemFontOfSize:20];
    [box addSubview:l];

    UIImageView *chev = [[UIImageView alloc] init];
    chev.translatesAutoresizingMaskIntoConstraints = NO;
    chev.contentMode = UIViewContentModeScaleAspectFit;
    chev.tintColor = [UIColor secondaryLabelColor];
    chev.contentMode = UIViewContentModeCenter;
    chev.image = [UIImage systemImageNamed:@"chevron.down" withConfiguration:ADXChevronConfig()];
    [box addSubview:chev];

    [NSLayoutConstraint activateConstraints:@[
        [accent.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:12],
        [accent.centerYAnchor constraintEqualToAnchor:box.centerYAnchor],
        [accent.widthAnchor constraintEqualToConstant:4],
        [accent.heightAnchor constraintEqualToConstant:22],

        [l.leadingAnchor constraintEqualToAnchor:accent.trailingAnchor constant:10],
        [l.centerYAnchor constraintEqualToAnchor:box.centerYAnchor],

        [chev.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-14],
        [chev.centerYAnchor constraintEqualToAnchor:box.centerYAnchor],
        [chev.widthAnchor constraintEqualToConstant:18],
        [chev.heightAnchor constraintEqualToConstant:18]
    ]];

    UITapGestureRecognizer *t = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                      action:@selector(headerTapped:)];
    [box addGestureRecognizer:t];
    box.tag = ball ? 1 : 2;

    if (ball) self.ballChevron = chev;
    else self.funcChevron = chev;

    return box;
}

- (void)headerTapped:(UITapGestureRecognizer *)g
{
    if (g.view.tag == 1) self.ballOpen = !self.ballOpen;
    else self.funcOpen = !self.funcOpen;
    [self applyCollapse];
}

- (void)toggleColor
{
    self.colorOpen = !self.colorOpen;
    [self applyCollapse];
}

- (void)applyCollapse
{
    BOOL ball = self.ballOpen;
    BOOL color = ball && self.colorOpen;
    BOOL func = self.funcOpen;

    // 不做动画：UIStackView 的 hidden 变化带隐式动画时，iPad 上会残留中间态位置
    [UIView performWithoutAnimation:^{
        for (UIView *v in self.ballViews) v.hidden = !ball;
        for (UIView *v in self.colorViews) v.hidden = !color;
        for (UIView *v in self.funcViews) v.hidden = !func;

        [self.ballChevron setImage:[UIImage systemImageNamed:(ball ? @"chevron.down" : @"chevron.right")
                                     withConfiguration:ADXChevronConfig()]];
        [self.funcChevron setImage:[UIImage systemImageNamed:(func ? @"chevron.down" : @"chevron.right")
                                     withConfiguration:ADXChevronConfig()]];
        self.colorChevron.image = [UIImage systemImageNamed:(self.colorOpen ? @"chevron.down" : @"chevron.right")
                                            withConfiguration:ADXChevronConfig()];

        [self.stack layoutIfNeeded];
        [self.scroll layoutIfNeeded];
    }];

    // 收起后内容变短，别让页面停在超出底部的位置
    CGFloat maxY = self.scroll.contentSize.height - self.scroll.bounds.size.height
                 + self.scroll.adjustedContentInset.bottom;
    if (maxY < 0) maxY = 0;
    if (self.scroll.contentOffset.y > maxY)
        [self.scroll setContentOffset:CGPointMake(0, maxY) animated:NO];
}

#pragma mark - 滚动时的板块提示

- (void)scrollViewDidScroll:(UIScrollView *)scroll
{
    if (!self.ballHeader || !self.funcHeader) return;

    CGFloat y = scroll.contentOffset.y;
    CGRect b = [self.ballHeader convertRect:self.ballHeader.bounds toView:scroll];
    CGRect f = [self.funcHeader convertRect:self.funcHeader.bounds toView:scroll];

    NSString *name = nil;
    if (CGRectGetMinY(f) <= y) name = @"功能";
    else if (CGRectGetMinY(b) <= y) name = @"悬浮球";

    if (name) {
        if (![self.sticky.text isEqualToString:name]) self.sticky.text = name;
        if (self.sticky.alpha < 1.0) self.sticky.alpha = 1.0;
    } else {
        if (self.sticky.alpha > 0.0) self.sticky.alpha = 0.0;
    }
}

- (UIStackView *)switchRow:(NSString *)title on:(BOOL)on action:(SEL)action
{
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;

    UILabel *l = [[UILabel alloc] init];
    l.text = title;
    l.font = [UIFont systemFontOfSize:14];
    l.numberOfLines = 0;

    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = on;
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];

    [row addArrangedSubview:l];
    [row addArrangedSubview:sw];
    return row;
}

- (UIStackView *)sliderRowForTextAlpha:(NSString *)unit
{
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 10;
    row.alignment = UIStackViewAlignmentCenter;

    UISlider *slider = [[UISlider alloc] init];
    [slider addTarget:self action:@selector(textAlphaSliderChanged)
     forControlEvents:UIControlEventValueChanged];

    UITextField *field = [[UITextField alloc] init];
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.textAlignment = NSTextAlignmentCenter;
    field.keyboardType = UIKeyboardTypeNumberPad;
    field.delegate = self;
    [field addTarget:self action:@selector(textAlphaFieldChanged)
    forControlEvents:UIControlEventEditingDidEnd];
    [field.widthAnchor constraintEqualToConstant:64].active = YES;
    [field.heightAnchor constraintEqualToConstant:36].active = YES;

    UILabel *unitLabel = [[UILabel alloc] init];
    unitLabel.text = unit;
    unitLabel.font = [UIFont systemFontOfSize:12];
    unitLabel.textColor = [UIColor secondaryLabelColor];

    [row addArrangedSubview:slider];
    [row addArrangedSubview:field];
    [row addArrangedSubview:unitLabel];

    self.textAlphaSlider = slider;
    self.textAlphaField = field;
    return row;
}

#pragma mark - 动作

- (void)triggerChanged
{
    [[NSUserDefaults standardUserDefaults] setInteger:self.triggerSeg.selectedSegmentIndex forKey:kTriggerKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:ADXSettingsChangedNotification object:nil];
}

- (void)colorTapped:(UIButton *)sender
{
    NSArray *palette = @[
        @"#4385F7", @"#4FC3F7", @"#26C6DA", @"#26A69A", @"#66BB6A",
        @"#9CCC65", @"#FFEE58", @"#FFCA28", @"#FFA726", @"#FF7043",
        @"#EF5350", @"#EC407A", @"#AB47BC", @"#7E57C2", @"#5C6BC0",
        @"#8D6E63", @"#9E9E9E", @"#607D8B", @"#212121", @"#F5F5F5"
    ];
    if (sender.tag < 0 || sender.tag >= (NSInteger)palette.count) return;
    [[NSUserDefaults standardUserDefaults] setObject:palette[sender.tag] forKey:kColorKey];
    [self refreshSwatches];
    [[NSNotificationCenter defaultCenter] postNotificationName:ADXSettingsChangedNotification object:nil];
}

- (void)refreshSwatches
{
    UIColor *current = [ADXSettings color];
    for (UIButton *b in self.swatches) {
        BOOL selected = [b.backgroundColor isEqual:current] ||
                        ([HexFromColor(b.backgroundColor) isEqualToString:HexFromColor(current)]);
        b.layer.borderWidth = selected ? 1.5 : 1;
        b.layer.borderColor = (selected ? [UIColor blackColor]
                                        : [UIColor colorWithWhite:0.88 alpha:1]).CGColor;
    }
}

- (void)applyAlpha:(CGFloat)pct
{
    pct = MIN(100, MAX(5, pct));
    self.alphaSlider.value = pct;
    self.alphaField.text = [NSString stringWithFormat:@"%d", (int)lround(pct)];
    [[NSUserDefaults standardUserDefaults] setDouble:pct / 100.0 forKey:kAlphaKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:ADXSettingsChangedNotification object:nil];
}

- (void)alphaSliderChanged { [self applyAlpha:self.alphaSlider.value]; }
- (void)alphaFieldChanged  { [self applyAlpha:[self.alphaField.text doubleValue]]; }

- (void)applyTextAlpha:(CGFloat)pct
{
    pct = MIN(100, MAX(0, pct));
    self.textAlphaSlider.value = pct;
    self.textAlphaField.text = [NSString stringWithFormat:@"%d", (int)lround(pct)];
    [[NSUserDefaults standardUserDefaults] setDouble:pct / 100.0 forKey:kTextAlphaKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:ADXSettingsChangedNotification object:nil];
}

- (void)textAlphaSliderChanged { [self applyTextAlpha:self.textAlphaSlider.value]; }
- (void)textAlphaFieldChanged  { [self applyTextAlpha:[self.textAlphaField.text doubleValue]]; }

- (void)toggleScores:(UISwitch *)sw
{
    [[NSUserDefaults standardUserDefaults] setBool:sw.isOn forKey:kShowScoresKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:ADXSettingsChangedNotification object:nil];
}

- (void)toggleB50:(UISwitch *)sw
{
    [[NSUserDefaults standardUserDefaults] setBool:sw.isOn forKey:kShowB50Key];
    [[NSNotificationCenter defaultCenter] postNotificationName:ADXSettingsChangedNotification object:nil];
}

- (void)toggleImage:(UISwitch *)sw
{
    [[NSUserDefaults standardUserDefaults] setBool:sw.isOn forKey:kShowImageKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:ADXSettingsChangedNotification object:nil];
}

- (void)toggleBrowse:(UISwitch *)sw
{
    [[NSUserDefaults standardUserDefaults] setBool:sw.isOn forKey:kShowBrowseKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:ADXSettingsChangedNotification object:nil];
}

- (void)refreshCoverCacheUI
{
    BOOL done = [ADXImage coversPreloaded];
    BOOL busy = self.preloading;

    NSString *title = busy ? @"取消加载" : (done ? @"已加载" : @"预加载曲绘");
    [self.preloadButton setTitle:title forState:UIControlStateNormal];
    self.preloadButton.enabled = busy || !done;
    self.preloadButton.backgroundColor = (done && !busy) ? [UIColor tertiarySystemFillColor] : ADXSteel();
    [self.preloadButton setTitleColor:(done && !busy) ? [UIColor secondaryLabelColor] : ADXSteelInk()
                             forState:UIControlStateNormal];
    [self.preloadButton setTitleColor:[UIColor secondaryLabelColor] forState:UIControlStateDisabled];

    if (busy) return;                 // 进度由 preloadTapped 的回调维护

    // 空闲时也把「已缓存多少」画出来，和微信/QQ 的缓存条一致
    NSInteger total = (NSInteger)[ADXChartDb songs].count;
    NSInteger have = [ADXImage cachedCoverCount];
    self.preloadProgress.hidden = NO;
    self.preloadProgress.progress = total ? (CGFloat)have / (CGFloat)total : 0;

    long pct = total ? (long)(have * 100 / total) : 0;
    NSString *used = ADXSizeText([ADXImage coverCacheSize]);
    if (done) {
        self.preloadLabel.text = [NSString stringWithFormat:
            @"已全部缓存 %ld 张 · 当前占用 %@ · 可随时删除。", (long)total, used];
    } else if (have > 0) {
        self.preloadLabel.text = [NSString stringWithFormat:
            @"已缓存 %ld / %ld（%ld%%）· 当前占用 %@ · 全部缓存约 150–200 MB。",
            (long)have, (long)total, pct, used];
    } else {
        self.preloadLabel.text = [NSString stringWithFormat:
            @"当前占用 %@。把全部曲绘缓存到本地约 150–200 MB，Wi-Fi 下大约 10–20 分钟。", used];
    }
}

- (void)preloadTapped
{
    if (self.preloading) {            // 再次点击 = 取消
        [ADXImage cancelPreload];
        self.preloading = NO;
        [self refreshCoverCacheUI];
        return;
    }

    if ([ADXImage coversPreloaded]) return;

    self.preloading = YES;
    NSInteger total = (NSInteger)[ADXChartDb songs].count;
    NSInteger have = [ADXImage cachedCoverCount];
    self.preloadProgress.progress = total ? (CGFloat)have / (CGFloat)total : 0;
    self.preloadLabel.text = [NSString stringWithFormat:@"正在预加载… %ld / %ld（%ld%%）",
                              (long)have, (long)total, total ? (long)(have * 100 / total) : 0];
    [self refreshCoverCacheUI];

    __weak typeof(self) weakSelf = self;
    [ADXImage preloadCoversWithProgress:^(NSInteger done, NSInteger all) {
        __typeof(weakSelf) me = weakSelf;
        if (!me || all <= 0) return;
        me.preloadProgress.progress = (float)done / (float)all;
        me.preloadLabel.text = [NSString stringWithFormat:@"正在预加载… %ld / %ld（%ld%%）",
                                (long)done, (long)all, (long)(done * 100 / all)];
    } completion:^(NSInteger cached) {
        __typeof(weakSelf) me = weakSelf;
        if (!me) return;
        me.preloading = NO;
        [me refreshCoverCacheUI];
    }];
}

- (UIViewController *)topPresenter
{
    UIWindow *win = self.view.window;
    if (!win) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { win = w; break; }
        }
    }
    UIViewController *host = win.rootViewController;
    while (host.presentedViewController) host = host.presentedViewController;
    return host;
}

- (void)clearCoversTapped
{
    NSInteger total = (NSInteger)[ADXChartDb songs].count;
    NSInteger have = [ADXImage cachedCoverCount];
    NSString *used = ADXSizeText([ADXImage coverCacheSize]);

    NSString *msg = [NSString stringWithFormat:@"当前已缓存 %ld / %ld 张，占用 %@。删除后浏览时会重新出现灰块。",
                     (long)have, (long)total, used];

    UIAlertController *step1 = [UIAlertController alertControllerWithTitle:@"删除曲绘缓存？"
                                                                  message:msg
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [step1 addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [step1 addAction:[UIAlertAction actionWithTitle:@"继续" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf askFinalConfirm];
    }]];
    [[self topPresenter] presentViewController:step1 animated:YES completion:nil];
}

- (void)askFinalConfirm
{
    UIAlertController *step2 = [UIAlertController alertControllerWithTitle:@"确认删除？"
                                                                  message:@"这一步不可撤销，删除后需要重新预加载才能恢复。"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [step2 addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [step2 addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        __typeof(weakSelf) me = weakSelf;
        if (!me) return;
        [ADXImage clearCovers];
        [me refreshCoverCacheUI];
    }]];
    [[self topPresenter] presentViewController:step2 animated:YES completion:nil];
}

- (void)applySize:(CGFloat)v
{
    v = MIN(96, MAX(40, v));
    self.sizeSlider.value = v;
    self.sizeField.text = [NSString stringWithFormat:@"%d", (int)lround(v)];
    [[NSUserDefaults standardUserDefaults] setDouble:v forKey:kSizeKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:ADXSettingsChangedNotification object:nil];
}

- (void)sizeSliderChanged { [self applySize:self.sizeSlider.value]; }
- (void)sizeFieldChanged  { [self applySize:[self.sizeField.text doubleValue]]; }

- (void)textChanged
{
    NSString *t = [self.textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (t.length == 0) t = @"ADX";
    if (t.length > 6) t = [t substringToIndex:6];
    self.textField.text = t;
    [[NSUserDefaults standardUserDefaults] setObject:t forKey:kTextKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:ADXSettingsChangedNotification object:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

@end
