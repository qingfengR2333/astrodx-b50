// SettingsPanel.h — 悬浮球设置（触发方式 / 颜色 / 透明度 / 文字 / 大小）
#import <UIKit/UIKit.h>

extern NSString *const ADXSettingsChangedNotification;

@interface ADXSettings : NSObject
+ (NSInteger)trigger;          // 0=单击 1=双击 2=长按
+ (UIColor *)color;
+ (CGFloat)alpha;              // 0.10 ~ 1.00
+ (NSString *)text;
+ (CGFloat)size;               // 40 ~ 96
@end

@interface ADXSettingsPanel : UIViewController
@end
