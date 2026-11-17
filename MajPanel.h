// MajPanel.h — 自制谱（majdata.net）模块
#import <UIKit/UIKit.h>

@interface ADXMajPanel : UIView

/// 点某一行打开详情时回调（一般传 nil，面板内部自己处理）
@property (nonatomic, copy) void (^onOpenSheet)(void);

- (void)reload;

@end
