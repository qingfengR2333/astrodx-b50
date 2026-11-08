// B50Image.h — 把 B50 结果画成一张 1600×1502 的 PNG（和 PC 版一个版式）
#import <UIKit/UIKit.h>
#import "B50Core.h"

@interface ADXImage : NSObject

/// 拉曲绘 → 画图 → 存 PNG。回调在主线程，image 可直接拿去分享。
+ (void)render:(ADXB50Result *)result
      coverDir:(NSString *)coverDir
        toPath:(NSString *)path
    completion:(void (^)(UIImage *image, NSError *error))completion;

@end
