// ImportPanel.m
#import "ImportPanel.h"
#import "Zip.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface ADXImportPanel ()
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, copy) NSString *pendingKind;
@end

@implementation ADXImportPanel

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"导入";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    UILabel *hint = [[UILabel alloc] init];
    hint.numberOfLines = 0;
    hint.font = [UIFont systemFontOfSize:13];
    hint.textColor = [UIColor secondaryLabelColor];
    hint.text = @"支持两种 .zip，可以多选：\n"
                 @"  · 单个谱面 / 皮肤 → 解压成 Documents/levels/<曲名>/、Documents/skins/<皮肤名>/\n"
                 @"  · 谱包（一个 zip 里装着很多 zip）→ 自动逐个解压，每个谱面一个独立文件夹\n"
                 @"导入完回到游戏，重开 App 或刷新曲库即可看到。";
    [stack addArrangedSubview:hint];

    // 钢蓝 #4682B4 提亮 40% ≈ #91B1D0
    UIColor *steel = [UIColor colorWithRed:0x91/255.0 green:0xB1/255.0 blue:0xD0/255.0 alpha:1.0];
    [stack addArrangedSubview:[self makeButton:@"导入谱面 / 谱包（.zip，可多选）" action:@selector(pickLevels) color:steel]];
    [stack addArrangedSubview:[self makeButton:@"导入皮肤 / 皮肤包（.zip，可多选）" action:@selector(pickSkins) color:steel]];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.hidesWhenStopped = YES;
    [stack addArrangedSubview:self.spinner];

    self.logView = [[UITextView alloc] init];
    self.logView.editable = NO;
    self.logView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.logView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.logView.layer.cornerRadius = 8;
    self.logView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    [stack addArrangedSubview:self.logView];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
        [self.logView.heightAnchor constraintGreaterThanOrEqualToConstant:160]
    ]];
}

- (UIButton *)makeButton:(NSString *)title action:(SEL)action color:(UIColor *)color
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor colorWithRed:0x20/255.0 green:0x36/255.0 blue:0x4F/255.0 alpha:1.0]
             forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    b.backgroundColor = color;
    b.layer.cornerRadius = 10;
    [b.heightAnchor constraintEqualToConstant:46].active = YES;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)pickLevels { [self pickWithKind:@"levels"]; }
- (void)pickSkins  { [self pickWithKind:@"skins"]; }

- (void)pickWithKind:(NSString *)kind
{
    // 用 iOS 14+ 的新接口，旧的 initWithDocumentTypes:inMode: 在新 SDK 里已被标记废弃，
    // 而构建链把废弃警告当成了错误
    UTType *zipType = [UTType typeWithIdentifier:@"public.zip-archive"];
    if (!zipType) zipType = [UTType typeWithFilenameExtension:@"zip"];
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[zipType] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
    self.pendingKind = kind;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
    if (urls.count == 0) return;
    NSString *kind = self.pendingKind.length ? self.pendingKind : @"levels";
    [self handleURLs:urls kind:kind];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    [self append:@"已取消"];
}

- (void)append:(NSString *)line
{
    NSString *old = self.logView.text ?: @"";
    self.logView.text = [old stringByAppendingFormat:@"%@\n", line];
    if (self.logView.text.length > 4000)
        self.logView.text = [self.logView.text substringFromIndex:self.logView.text.length - 3000];
    [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length, 0)];
}

- (void)handleURLs:(NSArray<NSURL *> *)urls kind:(NSString *)kind
{
    NSString *docs = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *parent = [docs stringByAppendingPathComponent:kind];
    [[NSFileManager defaultManager] createDirectoryAtPath:parent
                             withIntermediateDirectories:YES attributes:nil error:nil];

    [self.spinner startAnimating];
    [self append:[NSString stringWithFormat:@"开始导入 %lu 个文件 → Documents/%@/",
                  (unsigned long)urls.count, kind]];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        int ok = 0, fail = 0, dirs = 0;

        for (NSURL *u in urls) {
            NSError *err = nil;
            BOOL scoped = [u startAccessingSecurityScopedResource];
            NSArray *created = [ADXZip importPack:u.path into:parent error:&err];
            if (scoped) [u stopAccessingSecurityScopedResource];

            NSMutableArray *chunk = [NSMutableArray array];

            if (created.count == 0) {
                fail++;
                [chunk addObject:[NSString stringWithFormat:@"✗ %@：%@",
                                  u.lastPathComponent,
                                  err.localizedDescription ?: @"解压失败"]];
            } else {
                ok++;
                dirs += (int)created.count;

                if (created.count == 1) {
                    [chunk addObject:[NSString stringWithFormat:@"✓ %@ → %@/",
                                      u.lastPathComponent,
                                      [created[0] lastPathComponent]]];
                } else {
                    [chunk addObject:[NSString stringWithFormat:@"✓ %@ → 谱包，展开 %lu 个文件夹",
                                      u.lastPathComponent, (unsigned long)created.count]];
                    NSUInteger shown = 0;
                    for (NSString *d in created) {
                        if (shown >= 6) {
                            [chunk addObject:[NSString stringWithFormat:@"     … 还有 %lu 个",
                                              (unsigned long)(created.count - 6)]];
                            break;
                        }
                        [chunk addObject:[NSString stringWithFormat:@"     · %@/",
                                          d.lastPathComponent]];
                        shown++;
                    }
                }
            }

            // 一个文件处理完就刷一次日志，谱包很大时也不会像卡死
            dispatch_async(dispatch_get_main_queue(), ^{
                for (NSString *l in chunk) [self append:l];
            });
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self append:[NSString stringWithFormat:@"完成：成功 %d 个文件、失败 %d 个，共导入 %d 个文件夹",
                          ok, fail, dirs]];
            [self.spinner stopAnimating];
        });
    });
}

@end
