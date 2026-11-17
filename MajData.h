// MajData.h — majdata.net（自制谱）数据接口
#import <Foundation/Foundation.h>

@interface ADXMajData : NSObject

/// 默认列表 / 搜索。sort 传空字符串即默认排序。
+ (void)listWithSearch:(NSString *)keyword
                  sort:(NSString *)sort
                completion:(void (^)(NSArray *items, NSError *error))completion;

/// 榜单：sort 取 hotp(游玩) / playp(评价) / like(评论) / download(下载)
+ (void)rankingWithSort:(NSString *)sort
             completion:(void (^)(NSArray *items, NSError *error))completion;

/// 单谱面详情（结构与列表项一致）
+ (void)summaryOf:(NSString *)chartId
       completion:(void (^)(NSDictionary *info, NSError *error))completion;

/// 曲绘直链（128 大小即可）
+ (NSString *)imageURLOf:(NSString *)chartId;

/// 谱面难度：levels 是 7 个槽位（EASY / BASIC / ADVANCED / EXPERT / MASTER / Re:MASTER / 宴）
+ (NSArray *)levelTextsOf:(NSDictionary *)item;

/// 「No.」不适用，这里用上传者 + 时间做副标题
+ (NSString *)subtitleOf:(NSDictionary *)item;

/// 下载整包到 levels（逐个文件拉取后落盘），返回导入后的文件夹名
+ (void)download:(NSDictionary *)item
      includeBGA:(BOOL)includeBGA
        progress:(void (^)(CGFloat ratio, NSString *status))progress
      completion:(void (^)(NSString *folder, NSError *error))completion;


#pragma mark - 曲绘缓存（Library/Caches/majcovers）

/// 某张自制谱曲绘的本地路径
+ (NSString *)coverPathOf:(NSString *)chartId;

+ (NSInteger)coverCount;
+ (unsigned long long)coverCacheSize;
+ (BOOL)coversPreloaded;

/// 把 majdata 上所有谱面的曲绘下载到本地（分页遍历列表）
+ (void)preloadCoversWithProgress:(void (^)(NSInteger done, NSInteger total))progress
                       completion:(void (^)(NSInteger cached))completion;
+ (void)cancelCoverPreload;
+ (void)clearCovers;

#pragma mark - 收藏（存在 NSUserDefaults 的 majfavlist 里）

+ (NSArray *)favoriteItems;                     // [@{id,title,artist,designer}, ...]
+ (BOOL)isFavorite:(NSString *)chartId;
+ (void)toggleFavorite:(NSDictionary *)item;    // 传入列表项，内部整理字段

@end
