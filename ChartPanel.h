// ChartPanel.h — 「谱面查询」页：搜索框 + 候选曲目 + 曲目详情
#import <UIKit/UIKit.h>

@interface ADXChartPanel : UIView

/// 曲绘缓存目录（Documents/covers），没有就按 diving-fish 下载
@property (nonatomic, copy) NSString *coverDir;

/// 直接显示某首曲子的详情（按编号，B50 列表点进来用）
- (void)showSongById:(int)songId;

@end
