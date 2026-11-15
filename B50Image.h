// B50Image.h — 把 B50 结果画成一张 1600×1502 的 PNG（和 PC 版一个版式）
#import <UIKit/UIKit.h>
#import "B50Core.h"

@interface ADXImage : NSObject

/// 拉曲绘 → 画图 → 存 PNG。回调在主线程，image 可直接拿去分享。
+ (void)render:(ADXB50Result *)result
      coverDir:(NSString *)coverDir
        toPath:(NSString *)path
    completion:(void (^)(UIImage *image, NSError *error))completion;

/// 取曲绘：本地没有就按 diving-fish 的规则（先原号再 +10000）下载一次。
/// 会阻塞当前线程，别在主线程调。
+ (UIImage *)coverImageFor:(int)songId dir:(NSString *)dir;

/// 按直链取曲绘（日服独有曲目没有官方编号）。缓存文件名仍用 songId。
+ (UIImage *)coverImageFor:(int)songId url:(NSString *)url dir:(NSString *)dir;

/// 曲绘缓存目录（Library/Caches/covers，不会出现在「文件」App 里）
+ (NSString *)coverDir;

/// 把所有曲目的曲绘预加载到本地缓存；progress/completion 都在主线程回调
+ (void)preloadCoversWithProgress:(void (^)(NSInteger done, NSInteger total))progress
                       completion:(void (^)(NSInteger cached))completion;

/// 停止正在进行的预加载
+ (void)cancelPreload;

/// 已经缓存到本地的曲绘数量（预加载进度从这里起算）
+ (NSInteger)cachedCoverCount;

/// 曲绘缓存占用的磁盘空间（字节）
+ (unsigned long long)coverCacheSize;

/// 是否已经完整预加载过（用库目录里的标记文件判断）
+ (BOOL)coversPreloaded;

/// 清空曲绘缓存（内存 + 磁盘）
+ (void)clearCovers;

@end
