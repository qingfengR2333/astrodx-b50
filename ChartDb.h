// ChartDb.h — 内置曲库（来自 lxns 舞萌曲库），支持按编号 / 曲名 / 艺术家 / 别名搜索
#import <Foundation/Foundation.h>

@interface ADXChartDb : NSObject

/// 全部曲目。每首是 NSArray：id、曲名、艺术家、分类下标、BPM、版本码、发布年、别名、标准谱面、DX 谱面
+ (NSArray *)songs;

/// 关键词搜索，最多 limit 条
+ (NSArray *)search:(NSString *)keyword limit:(NSUInteger)limit;

/// 按编号取曲目（基础号与 DX 号都能命中），取不到返回 nil
+ (NSArray *)songById:(int)songId;

/// 是否有 DX 谱面
+ (BOOL)hasDx:(NSArray *)song;

/// 玩家习惯的编号：有 DX 谱面时是 10000 + 基础号（WIPE OUT MEMORIES → 11391）
+ (int)displayId:(NSArray *)song;

+ (NSString *)genreName:(NSArray *)song;

/// 「舞萌DX 2024」这种版本名
+ (NSString *)versionName:(NSArray *)song;

/// 某一边的谱面，按难度从高到低：每项是 [难度 0-4, 标准定数, 谱师, 物量]
+ (NSArray *)chartsOf:(NSArray *)song dx:(BOOL)dx;

/// 「14.9」这种定数文本
+ (NSString *)levelTextOfChart:(NSArray *)chart;

/// 谱师
+ (NSString *)designerOfChart:(NSArray *)chart;

/// 物量 [TAP, HOLD, SLIDE, TOUCH, BREAK]，没有数据时是 nil
+ (NSArray *)notesOfChart:(NSArray *)chart;

@end
