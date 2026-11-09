// ResourcePanel.m
#import "ResourcePanel.h"

#pragma mark - 列表单元格

@interface ADXResCell : UITableViewCell
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *subLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *sizeLabel;
@end

@implementation ADXResCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    _nameLabel = [UILabel new];
    _nameLabel.font = [UIFont systemFontOfSize:14];
    _subLabel = [UILabel new];
    _subLabel.font = [UIFont systemFontOfSize:11];
    _subLabel.textColor = [UIColor secondaryLabelColor];
    _dateLabel = [UILabel new];
    _dateLabel.font = [UIFont systemFontOfSize:11];
    _dateLabel.textColor = [UIColor secondaryLabelColor];
    _dateLabel.textAlignment = NSTextAlignmentRight;
    _sizeLabel = [UILabel new];
    _sizeLabel.font = [UIFont systemFontOfSize:11];
    _sizeLabel.textColor = [UIColor secondaryLabelColor];
    _sizeLabel.textAlignment = NSTextAlignmentRight;

    for (UILabel *l in @[_nameLabel, _subLabel, _dateLabel, _sizeLabel]) {
        l.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:l];
    }

    [NSLayoutConstraint activateConstraints:@[
        [_nameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_dateLabel.leadingAnchor constant:-8],

        [_subLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_subLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:2],
        [_subLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_sizeLabel.leadingAnchor constant:-8],

        [_dateLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [_dateLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [_dateLabel.widthAnchor constraintEqualToConstant:130],

        [_sizeLabel.trailingAnchor constraintEqualToAnchor:_dateLabel.trailingAnchor],
        [_sizeLabel.topAnchor constraintEqualToAnchor:_dateLabel.bottomAnchor constant:2],
        [_sizeLabel.widthAnchor constraintEqualToConstant:130]
    ]];
    return self;
}

@end

#pragma mark - 图标单元格

@interface ADXGridCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *countLabel;
@end

@implementation ADXGridCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    _iconView = [UIImageView new];
    _iconView.image = [UIImage systemImageNamed:@"folder.fill"];
    _iconView.tintColor = [UIColor systemTealColor];
    _iconView.contentMode = UIViewContentModeScaleAspectFit;

    _nameLabel = [UILabel new];
    _nameLabel.font = [UIFont systemFontOfSize:11];
    _nameLabel.numberOfLines = 2;
    _nameLabel.textAlignment = NSTextAlignmentCenter;

    _countLabel = [UILabel new];
    _countLabel.font = [UIFont systemFontOfSize:10];
    _countLabel.textColor = [UIColor secondaryLabelColor];
    _countLabel.textAlignment = NSTextAlignmentCenter;

    for (UIView *v in @[_iconView, _nameLabel, _countLabel]) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:v];
    }

    [NSLayoutConstraint activateConstraints:@[
        [_iconView.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [_iconView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
        [_iconView.widthAnchor constraintEqualToConstant:52],
        [_iconView.heightAnchor constraintEqualToConstant:44],

        [_nameLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:4],
        [_nameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:2],
        [_nameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-2],

        [_countLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:2],
        [_countLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_countLabel.trailingAnchor constraintEqualToAnchor:_nameLabel.trailingAnchor]
    ]];
    return self;
}

@end

#pragma mark - 主控制器

@interface ADXResourcePanel () <UITableViewDataSource, UITableViewDelegate,
                                UICollectionViewDataSource, UICollectionViewDelegate,
                                UISearchBarDelegate>
@property (nonatomic, strong) UISegmentedControl *segment;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIButton *filterBtn;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UICollectionView *grid;
@property (nonatomic, strong) UIButton *renameBtn;
@property (nonatomic, strong) UIButton *deleteBtn;
@property (nonatomic, strong) UIButton *refreshBtn;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UIBarButtonItem *selectAllItem;

@property (nonatomic, copy) NSString *kind;
@property (nonatomic, strong) NSMutableArray<NSString *> *allItems;
@property (nonatomic, strong) NSMutableArray<NSString *> *shownItems;
@property (nonatomic, strong) NSMutableSet<NSString *> *selected;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *dates;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *sizes;

@property (nonatomic, assign) NSInteger viewMode;   // 0 列表 1 图标
@property (nonatomic, assign) NSInteger sortMode;   // 0 名称 1 日期 2 大小
@end

@implementation ADXResourcePanel

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"资源管理";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.kind = @"levels";
    self.selected = [NSMutableSet set];
    self.dates = [NSMutableDictionary dictionary];
    self.sizes = [NSMutableDictionary dictionary];
    self.viewMode = 0;
    self.sortMode = 0;

    self.selectAllItem = [[UIBarButtonItem alloc] initWithTitle:@"全选"
                                                          style:UIBarButtonItemStylePlain
                                                         target:self
                                                         action:@selector(toggleSelectAll)];
    self.navigationItem.rightBarButtonItem = self.selectAllItem;

    self.segment = [[UISegmentedControl alloc] initWithItems:@[@"谱面管理", @"皮肤管理"]];
    self.segment.selectedSegmentIndex = 0;
    [self.segment addTarget:self action:@selector(segmentChanged) forControlEvents:UIControlEventValueChanged];

    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.placeholder = @"搜索文件夹名称";
    self.searchBar.delegate = self;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;

    self.filterBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.filterBtn setImage:[UIImage systemImageNamed:@"line.3.horizontal.decrease.circle"]
                    forState:UIControlStateNormal];
    self.filterBtn.tintColor = [UIColor systemBlueColor];
    [self.filterBtn addTarget:self action:@selector(showFilterMenu) forControlEvents:UIControlEventTouchUpInside];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.rowHeight = 60;
    self.table.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    UICollectionViewFlowLayout *flow = [UICollectionViewFlowLayout new];
    flow.minimumInteritemSpacing = 8;
    flow.minimumLineSpacing = 10;
    flow.sectionInset = UIEdgeInsetsMake(10, 16, 10, 16);
    self.grid = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:flow];
    self.grid.dataSource = self;
    self.grid.delegate = self;
    self.grid.backgroundColor = [UIColor systemBackgroundColor];
    self.grid.hidden = YES;
    [self.grid registerClass:[ADXGridCell class] forCellWithReuseIdentifier:@"grid"];

    self.countLabel = [UILabel new];
    self.countLabel.font = [UIFont systemFontOfSize:12];
    self.countLabel.textColor = [UIColor secondaryLabelColor];

    self.renameBtn = [self bottomButton:@"重命名" action:@selector(renameSelected) color:[UIColor systemBlueColor]];
    self.deleteBtn = [self bottomButton:@"删除" action:@selector(deleteSelected) color:[UIColor systemRedColor]];
    self.refreshBtn = [self bottomButton:@"刷新" action:@selector(reloadList) color:[UIColor systemBlueColor]];

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[self.renameBtn, self.deleteBtn, self.refreshBtn]];
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.spacing = 10;
    buttons.distribution = UIStackViewDistributionFillEqually;

    for (UIView *v in @[self.segment, self.searchBar, self.filterBtn, self.table, self.grid,
                        self.countLabel, buttons]) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:v];
    }

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.segment.topAnchor constraintEqualToAnchor:safe.topAnchor constant:10],
        [self.segment.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.segment.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],

        [self.filterBtn.centerYAnchor constraintEqualToAnchor:self.searchBar.centerYAnchor],
        [self.filterBtn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.filterBtn.widthAnchor constraintEqualToConstant:36],
        [self.filterBtn.heightAnchor constraintEqualToConstant:36],

        [self.searchBar.topAnchor constraintEqualToAnchor:self.segment.bottomAnchor constant:6],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.filterBtn.leadingAnchor constant:-4],

        [self.table.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor constant:4],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.countLabel.topAnchor constant:-4],

        [self.grid.topAnchor constraintEqualToAnchor:self.table.topAnchor],
        [self.grid.leadingAnchor constraintEqualToAnchor:self.table.leadingAnchor],
        [self.grid.trailingAnchor constraintEqualToAnchor:self.table.trailingAnchor],
        [self.grid.bottomAnchor constraintEqualToAnchor:self.table.bottomAnchor],

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

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    UICollectionViewFlowLayout *f = (UICollectionViewFlowLayout *)self.grid.collectionViewLayout;
    CGFloat w = self.grid.bounds.size.width;
    if (w <= 0) return;
    CGFloat usable = w - 32 - 24;
    CGFloat itemW = floor(usable / 4.0);
    if (f.itemSize.width != itemW) {
        f.itemSize = CGSizeMake(itemW, 116);
        [f invalidateLayout];
    }
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

#pragma mark - 目录与元信息

- (NSString *)directory
{
    NSString *docs = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *dir = [docs stringByAppendingPathComponent:self.kind];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                             withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

- (unsigned long long)sizeOf:(NSString *)name
{
    NSNumber *cached = self.sizes[name];
    if (cached) return cached.unsignedLongLongValue;

    NSString *dir = [[self directory] stringByAppendingPathComponent:name];
    unsigned long long total = 0;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *e = [fm enumeratorAtPath:dir];
    for (NSString *rel in e) {
        NSDictionary *attr = [fm attributesOfItemAtPath:[dir stringByAppendingPathComponent:rel] error:nil];
        total += [attr fileSize];
    }
    self.sizes[name] = @(total);
    return total;
}

- (NSUInteger)countOf:(NSString *)name
{
    NSString *dir = [[self directory] stringByAppendingPathComponent:name];
    return [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil].count;
}

- (NSString *)formatDate:(NSDate *)date
{
    if (!date) return @"";
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateFormatter *df = [NSDateFormatter new];
    if ([cal isDateInToday:date]) df.dateFormat = @"'今天' HH:mm";
    else if ([cal isDateInYesterday:date]) df.dateFormat = @"'昨天' HH:mm";
    else df.dateFormat = @"yyyy/M/d HH:mm";
    return [df stringFromDate:date];
}

- (NSString *)formatSize:(unsigned long long)b
{
    if (b >= 1024ULL * 1024 * 1024) return [NSString stringWithFormat:@"%.1f GB", b / 1073741824.0];
    if (b >= 1024ULL * 1024) return [NSString stringWithFormat:@"%.1f MB", b / 1048576.0];
    if (b >= 1024) return [NSString stringWithFormat:@"%.0f KB", b / 1024.0];
    return [NSString stringWithFormat:@"%llu B", b];
}

#pragma mark - 读取 / 过滤 / 排序

- (void)reloadList
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [self directory];
    NSArray *items = [fm contentsOfDirectoryAtPath:dir error:nil] ?: @[];

    NSMutableArray *dirs = [NSMutableArray array];
    [self.dates removeAllObjects];
    [self.sizes removeAllObjects];

    for (NSString *name in items) {
        BOOL isDir = NO;
        NSString *full = [dir stringByAppendingPathComponent:name];
        if ([fm fileExistsAtPath:full isDirectory:&isDir] && isDir) {
            [dirs addObject:name];
            NSDictionary *attr = [fm attributesOfItemAtPath:full error:nil];
            self.dates[name] = attr[NSFileModificationDate] ?: [NSDate distantPast];
        }
    }
    self.allItems = dirs;

    NSMutableSet *keep = [NSMutableSet set];
    for (NSString *n in self.selected) if ([dirs containsObject:n]) [keep addObject:n];
    self.selected = keep;

    [self applyFilter];
}

- (void)applyFilter
{
    NSString *q = [self.searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSMutableArray *list = [NSMutableArray array];
    for (NSString *n in self.allItems) {
        if (q.length == 0 || [n rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound)
            [list addObject:n];
    }

    if (self.sortMode == 1) {
        [list sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
            return [self.dates[b] compare:self.dates[a]];
        }];
    } else if (self.sortMode == 2) {
        for (NSString *n in list) [self sizeOf:n];
        [list sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
            return [self.sizes[b] compare:self.sizes[a]];
        }];
    } else {
        [list sortUsingSelector:@selector(localizedStandardCompare:)];
    }

    self.shownItems = list;
    [self.table reloadData];
    [self.grid reloadData];
    [self refreshSelectionUI];
}

- (void)refreshSelectionUI
{
    self.countLabel.text = [NSString stringWithFormat:@"共 %lu 个%@ · 已选 %lu 个",
                            (unsigned long)self.allItems.count,
                            [self.kind isEqualToString:@"levels"] ? @"谱面" : @"皮肤",
                            (unsigned long)self.selected.count];

    BOOL allSelected = self.shownItems.count > 0;
    for (NSString *n in self.shownItems) {
        if (![self.selected containsObject:n]) { allSelected = NO; break; }
    }
    self.selectAllItem.title = allSelected ? @"取消全选" : @"全选";
}

#pragma mark - 视图切换 / 排序菜单

- (void)showFilterMenu
{
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"筛选与排序"
                                                              message:nil
                                                       preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *viewTitle = self.viewMode == 0 ? @"切换为：图标视图" : @"切换为：列表视图";
    [a addAction:[UIAlertAction actionWithTitle:viewTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
        self.viewMode = self.viewMode == 0 ? 1 : 0;
        self.table.hidden = (self.viewMode == 1);
        self.grid.hidden = (self.viewMode == 0);
        [self applyFilter];
    }]];

    NSArray *sorts = @[@"按名称排序", @"按日期排序", @"按大小排序"];
    for (NSUInteger i = 0; i < sorts.count; i++) {
        NSString *prefix = (self.sortMode == (NSInteger)i) ? @"✓ " : @"";
        [a addAction:[UIAlertAction actionWithTitle:[prefix stringByAppendingString:sorts[i]]
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *x) {
            self.sortMode = (NSInteger)i;
            [self applyFilter];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView = self.filterBtn;
    a.popoverPresentationController.sourceRect = self.filterBtn.bounds;
    [self presentViewController:a animated:YES completion:nil];
}

- (void)segmentChanged
{
    self.kind = self.segment.selectedSegmentIndex == 0 ? @"levels" : @"skins";
    [self.selected removeAllObjects];
    [self reloadList];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText { [self applyFilter]; }
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar { [searchBar resignFirstResponder]; }

#pragma mark - 全选

- (void)toggleSelectAll
{
    if (self.shownItems.count == 0) return;
    BOOL all = YES;
    for (NSString *n in self.shownItems) {
        if (![self.selected containsObject:n]) { all = NO; break; }
    }
    if (all) [self.selected minusSet:[NSSet setWithArray:self.shownItems]];
    else [self.selected addObjectsFromArray:self.shownItems];

    [self.table reloadData];
    [self.grid reloadData];
    [self refreshSelectionUI];
}

#pragma mark - 表格

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.shownItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ADXResCell *cell = [tableView dequeueReusableCellWithIdentifier:@"res"];
    if (!cell) cell = [[ADXResCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"res"];

    NSString *name = self.shownItems[indexPath.row];
    cell.nameLabel.text = name;
    cell.subLabel.text = [NSString stringWithFormat:@"%lu 项", (unsigned long)[self countOf:name]];
    cell.dateLabel.text = [self formatDate:self.dates[name]];
    cell.sizeLabel.text = [self formatSize:[self sizeOf:name]];
    cell.accessoryType = [self.selected containsObject:name] ? UITableViewCellAccessoryCheckmark
                                                             : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    [self toggleSelection:self.shownItems[indexPath.row]];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    [self refreshSelectionUI];
}

#pragma mark - 网格

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)section
{
    return self.shownItems.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ADXGridCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"grid" forIndexPath:indexPath];
    NSString *name = self.shownItems[indexPath.row];
    cell.nameLabel.text = name;
    cell.countLabel.text = [NSString stringWithFormat:@"%lu 项", (unsigned long)[self countOf:name]];

    BOOL sel = [self.selected containsObject:name];
    cell.iconView.tintColor = sel ? [UIColor systemBlueColor] : [UIColor systemTealColor];
    cell.contentView.backgroundColor = sel
        ? [[UIColor systemBlueColor] colorWithAlphaComponent:0.12] : [UIColor clearColor];
    cell.contentView.layer.cornerRadius = 10;
    return cell;
}

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [self toggleSelection:self.shownItems[indexPath.row]];
    [cv reloadItemsAtIndexPaths:@[indexPath]];
    [self refreshSelectionUI];
}

- (void)toggleSelection:(NSString *)name
{
    if ([self.selected containsObject:name]) [self.selected removeObject:name];
    else [self.selected addObject:name];
}

#pragma mark - 重命名 / 删除

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
        [self performRename:oldName to:a.textFields.firstObject.text];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)performRename:(NSString *)oldName to:(NSString *)rawName
{
    NSString *newName = [rawName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (newName.length == 0) { [self alert:@"名称不能为空" message:nil]; return; }
    if ([newName containsString:@"/"] || [newName containsString:@":"]) {
        [self alert:@"名称不能包含 / 或 :" message:nil];
        return;
    }
    if ([newName isEqualToString:oldName]) return;

    for (NSString *n in self.allItems) {
        if (![n isEqualToString:oldName] && [n isEqualToString:newName]) {
            [self alert:@"文件名相同，请重新命名"
                 message:[NSString stringWithFormat:@"「%@」已经存在。", newName]];
            return;
        }
    }

    NSString *dir = [self directory];
    NSError *err = nil;
    if (![[NSFileManager defaultManager] moveItemAtPath:[dir stringByAppendingPathComponent:oldName]
                                                 toPath:[dir stringByAppendingPathComponent:newName]
                                                  error:&err]) {
        [self alert:@"重命名失败" message:err.localizedDescription];
        return;
    }
    [self.selected removeAllObjects];
    [self reloadList];
}

- (void)deleteSelected
{
    if (self.selected.count == 0) { [self alert:@"还没有选择" message:@"先勾选要删除的文件夹。"]; return; }

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
        for (NSString *p in paths) if (![fm removeItemAtPath:p error:nil]) failed++;
        [self.selected removeAllObjects];
        [self reloadList];
        if (failed) [self alert:@"部分删除失败" message:[NSString stringWithFormat:@"%d 个文件夹删除失败。", failed]];
    }]];
    a.popoverPresentationController.sourceView = self.view;
    a.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                            CGRectGetMidY(self.view.bounds), 1, 1);
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
