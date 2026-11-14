// ChartDownloadSheet.h — 「谱面下载」浮层：选线路 → 下载 → 自动导入 levels
#import <UIKit/UIKit.h>

@interface ADXChartDownloadSheet : UIView

/// 按当前曲目/标准-DX 弹出下载面板
+ (void)presentSong:(NSArray *)song dx:(BOOL)dx inView:(UIView *)host;

@end
