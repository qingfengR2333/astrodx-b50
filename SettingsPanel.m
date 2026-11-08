// SettingsPanel.m
#import "SettingsPanel.h"
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

static NSString *HexFromColor(UIColor *c)
{
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![c getRed:&r green:&g blue:&b alpha:&a]) return @"#4385F7";
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)lround(r * 255), (int)lround(g * 255), (int)lround(b * 255)];
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
    return ColorFromHex(hex.length ? hex : @"#4385F7");
}

+ (CGFloat)alpha
{
    id v = [[self d] objectForKey:kAlphaKey];
    return v ? [[self d] doubleForKey:kAlphaKey] : 0.92;
}

+ (NSString *)text
{
    NSString *t = [[self d] stringForKey:kTextKey];
    return t.length ? t : @"ADX";
}

+ (CGFloat)size
{
    id v = [[self d] objectForKey:kSizeKey];
    CGFloat s = v ? [[self d] doubleForKey:kSizeKey] : 56;
    return MIN(96, MAX(40, s));
}

+ (CGFloat)textAlpha
{
    id v = [[self d] objectForKey:kTextAlphaKey];
    CGFloat a = v ? [[self d] doubleForKey:kTextAlphaKey] : 1.0;
    return MIN(1.0, MAX(0.05, a));
}

+ (BOOL)showScoresButton
{
    id v = [[self d] objectForKey:kShowScoresKey];
    return v ? [[self d] boolForKey:kShowScoresKey] : YES;
}

+ (BOOL)showB50Button
{
    id v = [[self d] objectForKey:kShowB50Key];
    return v ? [[self d] boolForKey:kShowB50Key] : YES;
}

@end

#pragma mark - 面板

@interface ADXSettingsPanel () <UITextFieldDelegate>
@property (nonatomic, strong) UISlider *alphaSlider;
@property (nonatomic, strong) UISlider *textAlphaSlider;
@property (nonatomic, strong) UITextField *textAlphaField;
@property (nonatomic, strong) UISlider *sizeSlider;
@property (nonatomic, strong) UITextField *alphaField;
@property (nonatomic, strong) UITextField *sizeField;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UISegmentedControl *triggerSeg;
@property (nonatomic, strong) NSMutableArray<UIButton *> *swatches;

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
@end

@implementation ADXSettingsPanel

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"设置";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];

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

    [stack addArrangedSubview:[self bigTitle:@"悬浮球"]];

    // 1. 触发方式
    [stack addArrangedSubview:[self sectionTitle:@"触发方式"]];
    self.triggerSeg = [[UISegmentedControl alloc] initWithItems:@[@"单击", @"双击", @"长按"]];
    self.triggerSeg.selectedSegmentIndex = [ADXSettings trigger];
    [self.triggerSeg addTarget:self action:@selector(triggerChanged) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:self.triggerSeg];
    [stack addArrangedSubview:[self hint:@"只能选一个，用来替代原来的固定双击"]];

    [stack addArrangedSubview:[self spacer:10]];

    // 2. 颜色
    [stack addArrangedSubview:[self sectionTitle:@"颜色"]];
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
    self.textAlphaSlider.minimumValue = 5;
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

    [stack addArrangedSubview:[self spacer:18]];
    [stack addArrangedSubview:[self bigTitle:@"功能"]];
    [stack addArrangedSubview:[self switchRow:@"首页显示「导出分表」按钮"
                                          on:[ADXSettings showScoresButton]
                                      action:@selector(toggleScores:)]];
    [stack addArrangedSubview:[self switchRow:@"首页显示「导出 b50 表」按钮"
                                          on:[ADXSettings showB50Button]
                                      action:@selector(toggleB50:)]];

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
        b.layer.borderWidth = selected ? 3 : 1;
        b.layer.borderColor = (selected ? [UIColor labelColor] : [UIColor colorWithWhite:0.85 alpha:1]).CGColor;
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
    pct = MIN(100, MAX(5, pct));
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
