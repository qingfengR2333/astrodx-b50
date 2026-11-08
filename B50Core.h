// B50Core.h — AstroDX B50 悬浮窗的核心逻辑（解压 cache / 算 B50）
#import <Foundation/Foundation.h>

@interface ADXEntry : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *level;
@property (nonatomic, assign) double ds;
@property (nonatomic, assign) double rate;
@property (nonatomic, assign) int diffId;
@property (nonatomic, assign) int rating;
@property (nonatomic, assign) int rank;
@end

@interface ADXB50Result : NSObject
@property (nonatomic, strong) NSArray *oldList;     // ADXEntry，旧曲前 35
@property (nonatomic, strong) NSArray *newList;     // ADXEntry，新曲前 15
@property (nonatomic, assign) int oldSum;
@property (nonatomic, assign) int newSum;
@property (nonatomic, assign) int unmatched;
@property (nonatomic, assign) int current;      // 当前版本号，如 25500
@property (nonatomic, readonly) int total;      // oldSum + newSum
@end

@interface ADXB50 : NSObject

/// 读 Documents/cache 并解成 JSON 字典（raw deflate）
+ (NSDictionary *)readCacheAt:(NSString *)path error:(NSError **)error;

/// 取曲库（优先本地缓存，没有就联网拉一次）
+ (NSDictionary *)songDbInDir:(NSString *)dir error:(NSError **)error;

/// 计算 B50
+ (ADXB50Result *)computeWithCache:(NSDictionary *)cache db:(NSDictionary *)db;

@end
