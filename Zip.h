// Zip.h — 极简 zip 解压（只支持 store / deflate，够谱面和皮肤用）
#import <Foundation/Foundation.h>

@interface ADXZip : NSObject

/// 把 zip 解压到 parentDir 下、以"谱面/皮肤名称"命名的独立文件夹里。
/// 如果 zip 里所有条目都套在同一个顶层目录下（常见的打包方式），
/// 会自动剥掉那一层，避免出现 levels/曲名/曲名/... 的重复嵌套。
/// 返回创建出来的文件夹路径；失败返回 nil。
+ (NSString *)importZip:(NSString *)zipPath into:(NSString *)parentDir error:(NSError **)error;

/// 导入一个 zip，自动区分「单个谱面/皮肤」和「谱包」：
///   - 里面没有 .zip  → 当成单个谱面，解压成一个文件夹
///   - 里面有很多 .zip → 当成谱包，每个内层 zip 各自解压成独立文件夹
/// 返回所有新建的文件夹路径；一个都没建成时返回 nil。
+ (NSArray *)importPack:(NSString *)zipPath into:(NSString *)parentDir error:(NSError **)error;

@end
