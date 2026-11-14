// ChartFav.h — 收藏夹（存 NSUserDefaults）+ 收藏夹弹窗
#import <UIKit/UIKit.h>

@interface ADXChartFav : NSObject

/// 收藏的曲目 id，最近收藏在最前
+ (NSArray *)ids;

+ (BOOL)contains:(int)songId;

/// 切换收藏，返回切换后的状态
+ (BOOL)toggle:(int)songId;

/// 批量取消收藏（多选删除用）
+ (void)remove:(NSArray *)songIds;

@end

@interface ADXChartFavSheet : UIView

/// 弹出收藏夹；点某一行回调 songId（由调用方负责跳详情）
+ (void)presentInView:(UIView *)host open:(void (^)(int songId))open;

@end
