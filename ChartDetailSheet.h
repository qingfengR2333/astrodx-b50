// ChartDetailSheet.h — 点难度条弹出的「谱面详情」小窗（谱师 / 版本 / 物量 / 判定占比表）
#import <UIKit/UIKit.h>

@interface ADXChartSheet : UIView

/// 在 host（一般是面板的 window）上居中弹出；点背景关闭
+ (void)presentSong:(NSArray *)song
              chart:(NSArray *)chart
                 dx:(BOOL)dx
            version:(NSString *)version
           coverDir:(NSString *)coverDir
             inView:(UIView *)host;

@end
