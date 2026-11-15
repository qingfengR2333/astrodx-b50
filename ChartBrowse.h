// ChartBrowse.h — 「谱面查询」默认页：按 默认 / 类别 / 难度 / 版本 / 达成率 浏览曲库
#import <UIKit/UIKit.h>

@interface ADXChartBrowse : UIView

/// 点某一首（回调 songId）
@property (nonatomic, copy) void (^onSelect)(int songId);

/// 点右上「收藏夹」
@property (nonatomic, copy) void (^onFavorites)(void);

/// 重新生成列表（切换成绩或首次显示时调用）
- (void)reload;

@end
