// ResourcePanel.m
#import "ResourcePanel.h"

@interface ADXResourcePanel () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UISegmentedControl *segment;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UIButton *renameBtn;
@property (nonatomic, strong) UIButton *deleteBtn;
@property (nonatomic, strong) UIButton *refreshBtn;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, copy) NSString *kind;
@property (nonatomic, strong) NSMutableArray<NSString *> *allItems;
@property (nonatomic, strong) NSMutableArray<NSString *> *shownItems;
@property (nonatomic, strong) NSMutableSet<NSString *> *selected;
@end

@implementation ADXResourcePanel

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"资源管理";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.kind = @"levels";
    self.selected = [NSMutableSet set];

    self.segment = [[UISegmentedControl alloc] initWithItems:@[@"谱面管理", @"皮肤管理"]];
    self.segment.selectedSegmentIndex = 0;
    [self.segment addTarget:self action:@selector(segmentChanged) forControlEvents:UIControlEventValueChanged];

    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.placeholder = @"搜索文件夹名称";
    self.searchBar.delegate = self;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.rowHeight = 44;
    self.table.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    self.countLabel = [[UILabel alloc] init];
    self.countLabel.font = [UIFont systemFontOfSize:12];
    self.countLabel.textColor = [UIColor secondaryLabelColor];

    self.renameBtn = [self bottomButton:@"重命名" action:@selector(renameSelected) color:[UIColor systemBlueColor]];
    self.deleteBtn = [self bottomButton:@"删除" action:@selector(deleteSelected) color:[UIColor systemRedColor]];
    self.refreshBtn = [self bottomButton:@"刷新" action:@selector(reloadList) color:[UIColor systemBlueColor]];

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[self.renameBtn, self.deleteBtn, self.refreshBtn]];
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.spacing = 10;
    buttons.distribution = UIStackViewDistributionFillEqually;

    for (UIView *v in @[self.segment, self.searchBar, self.table, self.countLabel, buttons]) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:v];
    }

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.segment.topAnchor constraintEqualToAnchor:safe.topAnchor constant:10],
        [self.segment.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.segment.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],

        [self.searchBar.topAnchor constraintEqualToAnchor:self.segment.bottomAnchor constant:6],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],

        [self.table.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor constant:4],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.countLabel.topAnchor constant:-4],

        [self.countLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.countLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.countLabel.bottomAnchor constraintEqualToAnchor:buttons.topAnchor constant:-6],

        [buttons.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [buttons.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [buttons.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-10],
        [buttons.heightAnchor constraintEqualToConstant:44]
    ]];

    [self reloadList];
}

- (UIButton *)bottomButton:(NSString *)title action:(SEL)action color:(UIColor *)color
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:color forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    b.backgroundColor = [UIColor secondarySystemBackgroundColor];
    b.layer.cornerRadius = 10;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

#pragma mark - 数据

- (NSString *)directory
{
    NSString *docs = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *dir = [docs stringByAppendingPathComponent:self.kind];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                             withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

- (void)reloadList
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [self directory];
    NSArray *items = [fm contentsOfDirectoryAtPath:dir error:nil] ?: @[];
    NSMutableArray *dirs = [NSMutableArray array];
    for (NSString *name in items) {
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:[dir stringByAppendingPathComponent:name] isDirectory:&isDir] && isDir)
            [dirs addObject:name];
    }
    [dirs sortUsingSelector:@selector(localizedStandardCompare:)];
    self.allItems = dirs;

    // 去掉已不存在的选中项
    NSMutableSet *keep = [NSMutableSet set];
    for (NSString *n in self.selected) if ([dirs containsObject:n]) [keep addObject:n];
    self.selected = keep;

    [self applyFilter];
}

- (void)applyFilter
{
    NSString *q = [self.searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (q.length == 0) {
        self.shownItems = [self.allItems mutableCopy];
    } else {
        NSMutableArray *f = [NSMutableArray array];
        for (NSString *n in self.allItems)
            if ([n rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound) [f addObject:n];
        self.shownItems = f;
    }
    [self.table reloadData];
    self.countLabel.text = [NSString stringWithFormat:@"共 %lu 个%@ · 已选 %lu 个",
                            (unsigned long)self.allItems.count,
                            [self.kind isEqualToString:@"levels"] ? @"谱面" : @"皮肤",
                            (unsigned long)self.selected.count];
}

- (void)segmentChanged
{
    self.kind = self.segment.selectedSegmentIndex == 0 ? @"levels" : @"skins";
    [self.selected removeAllObjects];
    [self reloadList];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self applyFilter];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

#pragma mark - 表格

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.shownItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"res"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"res"];

    NSString *name = self.shownItems[indexPath.row];
    cell.textLabel.text = name;
    cell.textLabel.font = [UIFont systemFontOfSize:14];
    cell.accessoryType = [self.selected containsObject:name] ? UITableViewCellAccessoryCheckmark
                                                             : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    NSString *name = self.shownItems[indexPath.row];
    if ([self.selected containsObject:name]) [self.selected removeObject:name];
    else [self.selected addObject:name];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    [self applyFilter];
}

#pragma mark - 操作

- (void)renameSelected
{
    if (self.selected.count != 1) {
        [self alert:@"请只选择一个文件夹" message:@"重命名需要且只能选中一个。"];
        return;
    }
    NSString *oldName = self.selected.allObjects.firstObject;

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"重命名"
                                                              message:oldName
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.text = oldName; }];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
        NSString *newName = [[a.textFields.firstObject.text
                              stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
        [self performRename:oldName to:newName];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)performRename:(NSString *)oldName to:(NSString *)newName
{
    if (newName.length == 0) {
        [self alert:@"名称不能为空" message:nil];
        return;
    }
    if ([newName containsString:@"/"] || [newName containsString:@":"]) {
        [self alert:@"名称不能包含 / 或 :" message:nil];
        return;
    }
    if ([newName isEqualToString:oldName]) return;

    // 同名检测（排除自己）
    for (NSString *n in self.allItems) {
        if (![n isEqualToString:oldName] && [n isEqualToString:newName]) {
            [self alert:@"文件名相同，请重新命名"
                 message:[NSString stringWithFormat:@"「%@」已经存在。", newName]];
            return;
        }
    }

    NSString *dir = [self directory];
    NSError *err = nil;
    BOOL ok = [[NSFileManager defaultManager] moveItemAtPath:[dir stringByAppendingPathComponent:oldName]
                                                     toPath:[dir stringByAppendingPathComponent:newName]
                                                      error:&err];
    if (!ok) {
        [self alert:@"重命名失败" message:err.localizedDescription];
        return;
    }
    [self.selected removeAllObjects];
    [self reloadList];
}

- (void)deleteSelected
{
    if (self.selected.count == 0) {
        [self alert:@"还没有选择" message:@"先勾选要删除的文件夹。"];
        return;
    }

    NSString *dir = [self directory];
    NSMutableArray *paths = [NSMutableArray array];
    for (NSString *n in self.selected) [paths addObject:[dir stringByAppendingPathComponent:n]];

    UIAlertController *a = [UIAlertController
        alertControllerWithTitle:@"确认删除"
                         message:[NSString stringWithFormat:@"将删除 %lu 个文件夹，且不可恢复。",
                                  (unsigned long)paths.count]
                  preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *act) {
        NSFileManager *fm = [NSFileManager defaultManager];
        int failed = 0;
        for (NSString *p in paths) {
            NSError *err = nil;
            if (![fm removeItemAtPath:p error:&err]) failed++;
        }
        [self.selected removeAllObjects];
        [self reloadList];
        if (failed) [self alert:@"部分删除失败" message:[NSString stringWithFormat:@"%d 个文件夹删除失败。", failed]];
    }]];
    a.popoverPresentationController.sourceView = self.view;
    a.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:a animated:YES completion:nil];
}

- (void)alert:(NSString *)title message:(NSString *)message
{
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title
                                                              message:message
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
