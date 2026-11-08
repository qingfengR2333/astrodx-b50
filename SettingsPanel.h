// SettingsPanel.h — 悬浮球设置（触发方式 / 颜色 / 透明度 / 文字 / 大小）
#import <UIKit/UIKit.h>

extern NSString *const ADXSettingsChangedNotification;

@interface ADXSettings : NSObject
+ (NSInteger)trigger;          // 0=单击 1=双击 2=长按
+ (UIColor *)color;
+ (CGFloat)alpha;              // 背景透明度 0.05 ~ 1.00
+ (CGFloat)textAlpha;          // 文字透明度 0.05 ~ 1.00
+ (BOOL)showScoresButton;      // 首页是否显示「导出分表」
+ (BOOL)showB50Button;         // 首页是否显示「导出b50表」
+ (NSString *)text;
+ (CGFloat)size;               // 40 ~ 96
@end

@interface ADXSettingsPanel : UIViewController
@end
