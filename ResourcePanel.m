// ResourcePanel.m
#import "ResourcePanel.h"
#import <math.h>

#pragma mark - 列表单元格

@interface ADXResCell : UITableViewCell
@property (nonatomic, strong) UIImageView *folderIcon;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *subLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *sizeLabel;
@property (nonatomic, strong) UIImageView *checkView;
@property (nonatomic, strong) NSLayoutConstraint *nameToDate;
@property (nonatomic, strong) NSLayoutConstraint *nameToCheck;
- (void)setSelecting:(BOOL)selecting checked:(BOOL)checked;
@end

@implementation ADXResCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    _folderIcon = [UIImageView new];
    _folderIcon.image = [UIImage systemImageNamed:@"folder.fill"];
    _folderIcon.tintColor = [UIColor systemTealColor];
    _folderIcon.contentMode = UIViewContentModeScaleAspectFit;

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

    _checkView = [UIImageView new];
    _checkView.contentMode = UIViewContentModeScaleAspectFit;
    _checkView.hidden = YES;

    for (UIView *v in @[_folderIcon, _nameLabel, _subLabel, _dateLabel, _sizeLabel, _checkView]) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:v];
    }

    _nameToDate = [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_dateLabel.leadingAnchor constant:-8];
    _nameToCheck = [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_checkView.leadingAnchor constant:-8];
    _nameToCheck.active = NO;

    [NSLayoutConstraint activateConstraints:@[
        [_folderIcon.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [_folderIcon.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_folderIcon.widthAnchor constraintEqualToConstant:26],
        [_folderIcon.heightAnchor constraintEqualToConstant:22],

        [_nameLabel.leadingAnchor constraintEqualToAnchor:_folderIcon.trailingAnchor constant:10],
        [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:9],
        _nameToDate,

        [_subLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_subLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:2],
        [_subLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_dateLabel.leadingAnchor constant:-8],

        [_dateLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [_dateLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:9],
        [_dateLabel.widthAnchor constraintEqualToConstant:130],

        [_sizeLabel.trailingAnchor constraintEqualToAnchor:_dateLabel.trailingAnchor],
        [_sizeLabel.topAnchor constraintEqualToAnchor:_dateLabel.bottomAnchor constant:2],
        [_sizeLabel.widthAnchor constraintEqualToConstant:130],

        [_checkView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [_checkView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_checkView.widthAnchor constraintEqualToConstant:24],
        [_checkView.heightAnchor constraintEqualToConstant:24]
    ]];
    return self;
}

- (void)setSelecting:(BOOL)selecting checked:(BOOL)checked
{
    _dateLabel.hidden = selecting;
    _sizeLabel.hidden = selecting;
    _checkView.hidden = !selecting;

    _nameToDate.active = !selecting;
    _nameToCheck.active = selecting;

    _checkView.image = [UIImage systemImageNamed:checked ? @"checkmark.circle.fill" : @"circle"];
    _checkView.tintColor = checked ? [UIColor systemBlueColor] : [UIColor tertiaryLabelColor];

    self.contentView.backgroundColor = (selecting && checked)
        ? [[UIColor systemBlueColor] colorWithAlphaComponent:0.12]
        : [UIColor clearColor];
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
@property (nonatomic, strong) UIStackView *bottomBar;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UIBarButtonItem *selectItem;
@property (nonatomic, strong) UIBarButtonItem *selectAllItem;

@property (nonatomic, copy) NSString *kind;
@property (nonatomic, strong) NSMutableArray<NSString *> *allItems;
@property (nonatomic, strong) NSMutableArray<NSString *> *shownItems;
@property (nonatomic, strong) NSMutableSet<NSString *> *selected;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *dates;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *sizes;

@property (nonatomic, assign) NSInteger viewMode;   // 0 列表 1 图标
@property (nonatomic, assign) NSInteger sortMode;   // 0 名称 1 日期 2 大小

@property (nonatomic, assign) BOOL selecting;
@property (nonatomic, assign) BOOL dragging;
@property (nonatomic, assign) CGPoint dragPoint;
@property (nonatomic, assign) CGPoint startPoint;
@property (nonatomic, assign) NSInteger anchorIndex;     // 上一次选到的下标
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic, assign) CGFloat scrollSpeed;       // 每帧位移
@property (nonatomic, strong) NSLayoutConstraint *bottomHeight;
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

    self.selectItem = [[UIBarButtonItem alloc] initWithTitle:@"选择"
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(toggleSelectMode)];
    self.selectAllItem = [[UIBarButtonItem alloc] initWithTitle:@"全选"
                                                          style:UIBarButtonItemStylePlain
                                                         target:self
                                                         action:@selector(toggleSelectAll)];

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

    self.refreshBtn = [self bottomButton:@"刷新" action:@selector(reloadList) color:[UIColor systemBlueColor]];
    self.renameBtn = [self bottomButton:@"重命名" action:@selector(renameSelected) color:[UIColor systemBlueColor]];
    self.deleteBtn = [self bottomButton:@"删除" action:@selector(deleteSelected) color:[UIColor systemRedColor]];

    self.bottomBar = [[UIStackView alloc] initWithArrangedSubviews:@[self.refreshBtn, self.renameBtn, self.deleteBtn]];
    self.bottomBar.axis = UILayoutConstraintAxisHorizontal;
    self.bottomBar.spacing = 10;
    self.bottomBar.distribution = UIStackViewDistributionFillEqually;
    self.bottomBar.hidden = YES;

    for (UIView *v in @[self.segment, self.searchBar, self.filterBtn, self.table, self.grid,
                        self.countLabel, self.bottomBar]) {
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
        [self.countLabel.bottomAnchor constraintEqualToAnchor:self.bottomBar.topAnchor constant:-6],

        [self.bottomBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.bottomBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.bottomBar.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-10],
        self.bottomHeight = [self.bottomBar.heightAnchor constraintEqualToConstant:0],
        self.bottomHeight
    ]];

    UILongPressGestureRecognizer *tablePress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleTableLongPress:)];
    tablePress.minimumPressDuration = 0.35;
    [self.table addGestureRecognizer:tablePress];

    UILongPressGestureRecognizer *gridPress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleGridLongPress:)];
    gridPress.minimumPressDuration = 0.35;
    [self.grid addGestureRecognizer:gridPress];

    [self applySelectModeAppearance];
    [self reloadList];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.dragging = NO;
    [self stopLink];
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

#pragma mark - 选择模式

- (void)applySelectModeAppearance
{
    self.selectItem.title = self.selecting ? @"完成" : @"选择";
    // 数组第一个在最右边：完成 | 全选
    self.navigationItem.rightBarButtonItems = self.selecting
        ? @[self.selectItem, self.selectAllItem]
        : @[self.selectItem];
    self.bottomHeight.constant = self.selecting ? 44 : 0;
    self.bottomBar.hidden = !self.selecting;
    self.countLabel.hidden = NO;
}

- (void)toggleSelectMode
{
    self.selecting = !self.selecting;
    if (!self.selecting) [self.selected removeAllObjects];
    self.dragging = NO;
    [self stopLink];
    [self applySelectModeAppearance];
    [self.table reloadData];
    [self.grid reloadData];
    [self refreshSelectionUI];
}

- (void)enterSelectionMode
{
    if (self.selecting) return;
    self.selecting = YES;
    [self applySelectModeAppearance];
}

- (void)addToSelection:(NSString *)name
{
    if (!name) return;
    [self.selected addObject:name];
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

#pragma mark - 长按拖动选择

/// 手指离上下边缘越近，滚得越快（每帧像素）
- (CGFloat)speedForPoint:(CGPoint)p inScrollView:(UIScrollView *)sv
{
    CGFloat edge = 80;
    CGFloat h = sv.bounds.size.height;
    if (p.y < edge) return -((edge - p.y) / edge) * 16.0;
    if (p.y > h - edge) return ((p.y - (h - edge)) / edge) * 16.0;
    return 0;
}

- (void)startLinkIfNeeded
{
    if (self.link) return;
    self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(stepScroll:)];
    [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopLink
{
    [self.link invalidate];
    self.link = nil;
    self.scrollSpeed = 0;
}

- (void)stepScroll:(CADisplayLink *)link
{
    if (!self.dragging) { [self stopLink]; return; }

    UIScrollView *sv = (self.viewMode == 1) ? self.grid : self.table;
    if (fabs(self.scrollSpeed) < 0.4) return;

    CGFloat maxY = MAX(0, sv.contentSize.height - sv.bounds.size.height);
    CGFloat y = MAX(0, MIN(maxY, sv.contentOffset.y + self.scrollSpeed));
    if (y == sv.contentOffset.y) return;          // 到顶/到底，不再触发
    [sv setContentOffset:CGPointMake(sv.contentOffset.x, y) animated:NO];

    [self extendSelectionToPoint:self.dragPoint];
}

/// 把 anchorIndex 到当前手指所在下标的整段都选上，避免滚动时漏选
- (BOOL)selectRangeToIndex:(NSInteger)idx
{
    NSInteger a = MIN(self.anchorIndex, idx);
    NSInteger b = MAX(self.anchorIndex, idx);
    BOOL changed = NO;
    for (NSInteger i = a; i <= b; i++) {
        if (i < 0 || i >= (NSInteger)self.shownItems.count) continue;
        NSString *n = self.shownItems[i];
        if (![self.selected containsObject:n]) {
            [self.selected addObject:n];
            changed = YES;
        }
    }
    self.anchorIndex = idx;
    return changed;
}

- (void)extendSelectionToPoint:(CGPoint)p
{
    BOOL changed = NO;
    if (self.viewMode == 1) {
        NSIndexPath *ip = [self.grid indexPathForItemAtPoint:p];
        if (ip) changed = [self selectRangeToIndex:ip.item];
    } else {
        NSIndexPath *ip = [self.table indexPathForRowAtPoint:p];
        if (ip) changed = [self selectRangeToIndex:ip.row];
    }
    if (changed) [self refreshVisibleCells];
}

/// 只改可见单元格，不 reloadData，滚动时不掉帧
- (void)refreshVisibleCells
{
    if (self.viewMode == 1) {
        for (ADXGridCell *c in self.grid.visibleCells) {
            NSIndexPath *ip = [self.grid indexPathForCell:c];
            if (ip.item < (NSInteger)self.shownItems.count)
                [self configureGridCell:c name:self.shownItems[ip.item]];
        }
    } else {
        for (ADXResCell *c in self.table.visibleCells) {
            NSIndexPath *ip = [self.table indexPathForCell:c];
            if (ip.row < (NSInteger)self.shownItems.count) {
                NSString *n = self.shownItems[ip.row];
                [c setSelecting:self.selecting checked:[self.selected containsObject:n]];
            }
        }
    }
    [self refreshSelectionUI];
}

- (void)handleTableLongPress:(UILongPressGestureRecognizer *)g
{
    CGPoint p = [g locationInView:self.table];

    if (g.state == UIGestureRecognizerStateBegan) {
        NSIndexPath *ip = [self.table indexPathForRowAtPoint:p];
        if (!ip) return;

        [self enterSelectionMode];
        [self.table reloadData];

        self.dragging = YES;
        self.dragPoint = p;
        self.startPoint = p;
        self.anchorIndex = ip.row;
        [self.selected addObject:self.shownItems[ip.row]];
        [self refreshVisibleCells];
        self.scrollSpeed = 0;                 // 还没拖动，先不滚
    } else if (g.state == UIGestureRecognizerStateChanged) {
        if (!self.dragging) return;
        self.dragPoint = p;

        BOOL moved = (fabs(p.y - self.startPoint.y) > 6 || fabs(p.x - self.startPoint.x) > 6);
        if (moved) {
            NSIndexPath *ip = [self.table indexPathForRowAtPoint:p];
            if (ip) [self selectRangeToIndex:ip.row];
            self.scrollSpeed = [self speedForPoint:p inScrollView:self.table];
            if (self.scrollSpeed != 0) [self startLinkIfNeeded];
            else [self stopLink];
            [self refreshVisibleCells];
        }
    } else {
        self.dragging = NO;
        [self stopLink];
    }
}

- (void)handleGridLongPress:(UILongPressGestureRecognizer *)g
{
    CGPoint p = [g locationInView:self.grid];

    if (g.state == UIGestureRecognizerStateBegan) {
        NSIndexPath *ip = [self.grid indexPathForItemAtPoint:p];
        if (!ip) return;

        [self enterSelectionMode];
        [self.grid reloadData];

        self.dragging = YES;
        self.dragPoint = p;
        self.startPoint = p;
        self.anchorIndex = ip.item;
        [self.selected addObject:self.shownItems[ip.item]];
        [self refreshVisibleCells];
        self.scrollSpeed = 0;
    } else if (g.state == UIGestureRecognizerStateChanged) {
        if (!self.dragging) return;
        self.dragPoint = p;

        BOOL moved = (fabs(p.y - self.startPoint.y) > 6 || fabs(p.x - self.startPoint.x) > 6);
        if (moved) {
            NSIndexPath *ip = [self.grid indexPathForItemAtPoint:p];
            if (ip) [self selectRangeToIndex:ip.item];
            self.scrollSpeed = [self speedForPoint:p inScrollView:self.grid];
            if (self.scrollSpeed != 0) [self startLinkIfNeeded];
            else [self stopLink];
            [self refreshVisibleCells];
        }
    } else {
        self.dragging = NO;
        [self stopLink];
    }
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
    [cell setSelecting:self.selecting checked:[self.selected containsObject:name]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    if (!self.selecting) return;

    NSString *name = self.shownItems[indexPath.row];
    [self toggleSelection:name];
    [self.table reloadData];
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
    [self configureGridCell:cell name:self.shownItems[indexPath.row]];
    return cell;
}

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!self.selecting) return;
    [self toggleSelection:self.shownItems[indexPath.row]];
    [cv reloadData];
    [self refreshSelectionUI];
}

- (void)configureGridCell:(ADXGridCell *)cell name:(NSString *)name
{
    cell.nameLabel.text = name;
    cell.countLabel.text = [NSString stringWithFormat:@"%lu 项", (unsigned long)[self countOf:name]];

    BOOL sel = self.selecting && [self.selected containsObject:name];
    cell.iconView.tintColor = sel ? [UIColor systemBlueColor] : [UIColor systemTealColor];
    cell.contentView.backgroundColor = sel
        ? [[UIColor systemBlueColor] colorWithAlphaComponent:0.12] : [UIColor clearColor];
    cell.contentView.layer.cornerRadius = 10;
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
