// B50Core.m
#import "B50Core.h"
#import <zlib.h>
#import <math.h>
#import <string.h>

@implementation ADXEntry
@end


#pragma mark - CSV

static NSString *CsvCell(NSString *v)
{
    if (!v) return @"";
    if ([v rangeOfString:@","].location != NSNotFound ||
        [v rangeOfString:@"\""].location != NSNotFound ||
        [v rangeOfString:@"\n"].location != NSNotFound) {
        return [NSString stringWithFormat:@"\"%@\"", [v stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
    }
    return v;
}

+ (NSString *)scoresCsv:(NSDictionary *)cache playedOnly:(BOOL)only
{
    NSMutableString *s = [NSMutableString stringWithString:
        @"level_key,path,title,artist,difficulty_id,difficulty,charter,"
        @"achievementRate,clearType,dxScore,maxCombo,clearedPlays,completePlays,"
        @"criticalCount,perfectCount,greatCount,goodCount,totalNotesCount\r\n"];

    NSDictionary *levels = cache[@"level_metadata"];
    if (![levels isKindOfClass:[NSDictionary class]]) return s;

    for (NSString *key in levels) {
        NSDictionary *lv = levels[key];
        NSArray *diffs = lv[@"difficulties"];
        if (![diffs isKindOfClass:[NSArray class]]) continue;

        for (NSDictionary *d in diffs) {
            NSDictionary *st = d[@"stats"];
            if (![st isKindOfClass:[NSDictionary class]]) st = @{};

            double rate = [st[@"achievementRate"] doubleValue];
            int dxScore = [st[@"dxScore"] intValue];
            int plays = [st[@"clearedPlays"] intValue];
            if (only && rate <= 0 && dxScore <= 0 && plays <= 0) continue;

            NSMutableArray *f = [NSMutableArray array];
            [f addObject:CsvCell(key)];
            [f addObject:CsvCell(lv[@"path"])];
            [f addObject:CsvCell(lv[@"title"])];
            [f addObject:CsvCell(lv[@"artist"])];
            [f addObject:[NSString stringWithFormat:@"%d", [d[@"id"] intValue]]];
            [f addObject:CsvCell(d[@"value"])];
            [f addObject:CsvCell(d[@"charter"])];
            [f addObject:[NSString stringWithFormat:@"%.9g", rate]];
            [f addObject:[NSString stringWithFormat:@"%d", [st[@"clearType"] intValue]]];
            [f addObject:[NSString stringWithFormat:@"%d", dxScore]];
            [f addObject:[NSString stringWithFormat:@"%d", [st[@"maxCombo"] intValue]]];
            [f addObject:[NSString stringWithFormat:@"%d", plays]];
            [f addObject:[NSString stringWithFormat:@"%d", [st[@"completePlays"] intValue]]];
            [f addObject:[NSString stringWithFormat:@"%d", [st[@"criticalCount"] intValue]]];
            [f addObject:[NSString stringWithFormat:@"%d", [st[@"perfectCount"] intValue]]];
            [f addObject:[NSString stringWithFormat:@"%d", [st[@"greatCount"] intValue]]];
            [f addObject:[NSString stringWithFormat:@"%d", [st[@"goodCount"] intValue]]];
            [f addObject:[NSString stringWithFormat:@"%d", [st[@"totalNotesCount"] intValue]]];
            [s appendString:[f componentsJoinedByString:@","]];
            [s appendString:@"\r\n"];
        }
    }
    return s;
}

+ (NSString *)b50Csv:(ADXB50Result *)result
{
    NSMutableString *s = [NSMutableString stringWithString:
        @"section,rank,title,type,difficulty,level,ds,achievementRate,rating\r\n"];
    if (!result) return s;

    for (int pass = 0; pass < 2; pass++) {
        NSArray *list = pass == 0 ? result.oldList : result.recentList;
        NSString *section = pass == 0 ? @"old" : @"new";
        for (ADXEntry *e in list) {
            NSString *type = @"";
            if ([e.title hasSuffix:@"]"]) {
                NSRange r = [e.title rangeOfString:@"[" options:NSBackwardsSearch];
                if (r.location != NSNotFound) {
                    NSString *inner = [e.title substringFromIndex:r.location + 1];
                    inner = [inner substringToIndex:inner.length - 1];
                    if ([inner caseInsensitiveCompare:@"DX"] == NSOrderedSame) type = @"DX";
                    else if ([inner caseInsensitiveCompare:@"SD"] == NSOrderedSame) type = @"SD";
                }
            }
            [s appendFormat:@"%@,%d,%@,%@,%@,%@,%.1f,%.4f,%d\r\n",
             section, e.rank, CsvCell(e.title), type, CsvCell(e.level), CsvCell(e.level),
             e.ds, e.rate, e.rating];
        }
    }
    return s;
}

@implementation ADXB50Result
- (int)total { return self.oldSum + self.newSum; }
@end

#pragma mark - 工具

static NSString *ADXNorm(NSString *s)
{
    if (s.length == 0) return @"";
    NSString *t = [s stringByReplacingOccurrencesOfString:@"　" withString:@" "];
    t = [t stringByReplacingOccurrencesOfString:@"～" withString:@"~"];
    t = [t stringByReplacingOccurrencesOfString:@"’" withString:@"'"];
    t = [t stringByReplacingOccurrencesOfString:@"‘" withString:@"'"];
    t = [t stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([t rangeOfString:@"  "].location != NSNotFound)
        t = [t stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    return [t lowercaseString];
}

static void ADXSplitType(NSString *title, NSString **base, NSString **type)
{
    NSString *t = title ?: @"";
    *base = t;
    *type = nil;
    if (t.length < 4 || ![t hasSuffix:@"]"]) return;
    NSRange r = [t rangeOfString:@"[" options:NSBackwardsSearch];
    if (r.location == NSNotFound) return;
    NSString *inner = [[t substringWithRange:NSMakeRange(r.location + 1, t.length - r.location - 2)] uppercaseString];
    if ([inner isEqualToString:@"DX"] || [inner isEqualToString:@"SD"]) {
        *base = [[t substringToIndex:r.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        *type = inner;
    }
}

static double ADXCoef(double rate)
{
    if (rate >= 100.5) return 22.4;
    if (rate >= 100.0) return 21.6;
    if (rate >= 99.5) return 21.1;
    if (rate >= 99.0) return 20.8;
    if (rate >= 98.0) return 20.3;
    if (rate >= 97.0) return 20.0;
    if (rate >= 94.0) return 16.8;
    if (rate >= 90.0) return 15.2;
    if (rate >= 80.0) return 13.6;
    if (rate >= 75.0) return 12.0;
    if (rate >= 70.0) return 11.2;
    if (rate >= 60.0) return 9.6;
    if (rate >= 50.0) return 8.0;
    return 0;
}

static NSData *ADXSyncGet(NSString *url, NSError **error)
{
    NSURL *u = [NSURL URLWithString:url];
    if (!u) {
        if (error) *error = [NSError errorWithDomain:@"ADX" code:1 userInfo:@{NSLocalizedDescriptionKey: @"URL 无效"}];
        return nil;
    }
    __block NSData *result = nil;
    __block NSError *err = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest = 25;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];
    [[session dataTaskWithURL:u completionHandler:^(NSData *data, NSURLResponse *resp, NSError *e) {
        result = data;
        err = e;
        dispatch_semaphore_signal(sem);
    }] resume];

    if (dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC))) != 0) {
        if (error) *error = [NSError errorWithDomain:@"ADX" code:2 userInfo:@{NSLocalizedDescriptionKey: @"网络请求超时"}];
        return nil;
    }
    if (!result && error) *error = err ?: [NSError errorWithDomain:@"ADX" code:3 userInfo:@{NSLocalizedDescriptionKey: @"网络请求失败"}];
    return result;
}

#pragma mark - 主体

@implementation ADXB50

+ (NSData *)inflateRaw:(NSData *)data
{
    if (data.length < 2) return nil;
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    if (bytes[0] == '{') return data;                 // 已经是明文 JSON

    z_stream zs;
    memset(&zs, 0, sizeof(zs));
    if (inflateInit2(&zs, -15) != Z_OK) return nil;

    NSMutableData *out = [NSMutableData dataWithCapacity:data.length * 12];
    uint8_t buf[65536];
    zs.next_in = (Bytef *)bytes;
    zs.avail_in = (uInt)data.length;

    int ret = Z_OK;
    while (ret != Z_STREAM_END) {
        zs.next_out = buf;
        zs.avail_out = sizeof(buf);
        ret = inflate(&zs, Z_NO_FLUSH);
        if (ret != Z_OK && ret != Z_STREAM_END) break;
        [out appendBytes:buf length:sizeof(buf) - zs.avail_out];
        if (zs.avail_in == 0 && ret != Z_STREAM_END) break;
    }
    inflateEnd(&zs);
    return (ret == Z_STREAM_END) ? out : nil;
}

+ (NSDictionary *)readCacheAt:(NSString *)path error:(NSError **)error
{
    NSData *raw = [NSData dataWithContentsOfFile:path];
    if (!raw) {
        if (error) *error = [NSError errorWithDomain:@"ADX" code:10
                                            userInfo:@{NSLocalizedDescriptionKey:
                                                       [NSString stringWithFormat:@"读不到 cache：\n%@", path]}];
        return nil;
    }
    NSData *json = [self inflateRaw:raw];
    if (!json) {
        if (error) *error = [NSError errorWithDomain:@"ADX" code:11
                                            userInfo:@{NSLocalizedDescriptionKey: @"解压失败，这个文件不是 AstroDX 的 cache"}];
        return nil;
    }
    NSError *e = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:json options:0 error:&e];
    if (![obj isKindOfClass:[NSDictionary class]]) {
        if (error) *error = e ?: [NSError errorWithDomain:@"ADX" code:12
                                                 userInfo:@{NSLocalizedDescriptionKey: @"JSON 解析失败"}];
        return nil;
    }
    return obj;
}

+ (NSDictionary *)songDbInDir:(NSString *)dir error:(NSError **)error
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [dir stringByAppendingPathComponent:@"astrodxb50_db.json"];

    NSData *raw = nil;
    if ([fm fileExistsAtPath:path]) {
        NSDictionary *attr = [fm attributesOfItemAtPath:path error:nil];
        NSDate *mtime = attr[NSFileModificationDate];
        if (!mtime || -[mtime timeIntervalSinceNow] < 14 * 86400.0)
            raw = [NSData dataWithContentsOfFile:path];
    }
    if (!raw) {
        raw = ADXSyncGet(@"https://maimai.lxns.net/api/v0/maimai/song/list", error);
        if (!raw) return nil;
        [raw writeToFile:path atomically:YES];
    }

    id root = [NSJSONSerialization JSONObjectWithData:raw options:0 error:nil];
    NSArray *songs = [root isKindOfClass:[NSDictionary class]] ? root[@"songs"] : nil;
    if (![songs isKindOfClass:[NSArray class]]) {
        if (error) *error = [NSError errorWithDomain:@"ADX" code:20
                                            userInfo:@{NSLocalizedDescriptionKey: @"曲库数据格式不对"}];
        return nil;
    }

    NSMutableDictionary *map = [NSMutableDictionary dictionaryWithCapacity:6000];
    int maxVer = 0;

    for (NSDictionary *song in songs) {
        int sid = [song[@"id"] intValue];
        NSString *title = song[@"title"];
        NSDictionary *diffs = song[@"difficulties"];
        if (![title isKindOfClass:[NSString class]] || ![diffs isKindOfClass:[NSDictionary class]]) continue;

        for (NSString *type in @[@"SD", @"DX"]) {
            NSArray *charts = [type isEqualToString:@"SD"] ? diffs[@"standard"] : diffs[@"dx"];
            if (![charts isKindOfClass:[NSArray class]]) continue;
            for (NSDictionary *c in charts) {
                int idx = [c[@"difficulty"] intValue];
                double ds = [c[@"level_value"] doubleValue];
                int ver = [c[@"version"] intValue];
                if (ver > maxVer) maxVer = ver;
                NSString *key = [NSString stringWithFormat:@"%@|%@|%d", ADXNorm(title), type, idx];
                map[key] = @{@"ds": @(ds), @"level": c[@"level"] ?: @"", @"ver": @(ver), @"id": @(sid)};
            }
        }
    }

    int current = (maxVer / 100) * 100;
    return @{@"current": @(current), @"map": map, @"count": @(map.count)};
}

+ (ADXB50Result *)computeWithCache:(NSDictionary *)cache db:(NSDictionary *)db
{
    ADXB50Result *res = [ADXB50Result new];
    NSDictionary *map = db[@"map"];
    int current = [db[@"current"] intValue];
    res.current = current;

    NSMutableArray *all = [NSMutableArray array];
    int unmatched = 0;

    NSDictionary *levels = cache[@"level_metadata"];
    if (![levels isKindOfClass:[NSDictionary class]]) levels = @{};

    for (NSString *key in levels) {
        NSDictionary *lv = levels[key];
        if (![lv isKindOfClass:[NSDictionary class]]) continue;
        NSArray *diffs = lv[@"difficulties"];
        if (![diffs isKindOfClass:[NSArray class]]) continue;

        NSString *title = lv[@"title"];

        for (NSDictionary *d in diffs) {
            NSDictionary *st = d[@"stats"];
            if (![st isKindOfClass:[NSDictionary class]]) continue;

            double rate = [st[@"achievementRate"] doubleValue];
            int dxScore = [st[@"dxScore"] intValue];
            int plays = [st[@"clearedPlays"] intValue];
            if (rate <= 0 && dxScore <= 0 && plays <= 0) continue;

            int diffId = [d[@"id"] intValue];
            if (diffId < 2 || diffId > 6) { unmatched++; continue; }

            NSString *base = nil, *type = nil;
            ADXSplitType(title, &base, &type);

            NSDictionary *hit = nil;
            if (type) {
                hit = map[[NSString stringWithFormat:@"%@|%@|%d", ADXNorm(base), type, diffId - 2]];
            } else {
                hit = map[[NSString stringWithFormat:@"%@|DX|%d", ADXNorm(base), diffId - 2]];
                if (!hit) hit = map[[NSString stringWithFormat:@"%@|SD|%d", ADXNorm(base), diffId - 2]];
            }
            if (!hit) { unmatched++; continue; }

            ADXEntry *e = [ADXEntry new];
            e.title = title ?: @"";
            e.level = hit[@"level"];
            e.ds = [hit[@"ds"] doubleValue];
            e.rate = rate;
            e.diffId = diffId;
            e.rating = (int)floor(e.ds * ADXCoef(rate) + 1e-9);
            e.songId = [hit[@"id"] intValue];
            [all addObject:e];
        }
    }

    NSMutableArray *oldPool = [NSMutableArray array], *newPool = [NSMutableArray array];

    // 按版本拆新旧：重新遍历一次，用同一套 key 取 version
    for (ADXEntry *e in all) {
        NSString *base = nil, *type = nil;
        ADXSplitType(e.title, &base, &type);
        NSDictionary *hit = nil;
        if (type) hit = map[[NSString stringWithFormat:@"%@|%@|%d", ADXNorm(base), type, e.diffId - 2]];
        else {
            hit = map[[NSString stringWithFormat:@"%@|DX|%d", ADXNorm(base), e.diffId - 2]];
            if (!hit) hit = map[[NSString stringWithFormat:@"%@|SD|%d", ADXNorm(base), e.diffId - 2]];
        }
        int ver = [hit[@"ver"] intValue];
        if (ver >= current) [newPool addObject:e];
        else [oldPool addObject:e];
    }

    NSArray *(^sorted)(NSArray *) = ^NSArray *(NSArray *arr) {
        return [arr sortedArrayUsingComparator:^NSComparisonResult(ADXEntry *a, ADXEntry *b) {
            if (a.rating != b.rating) return a.rating > b.rating ? NSOrderedAscending : NSOrderedDescending;
            if (a.rate != b.rate) return a.rate > b.rate ? NSOrderedAscending : NSOrderedDescending;
            return [a.title compare:b.title];
        }];
    };

    NSMutableArray *oldTop = [NSMutableArray array], *newTop = [NSMutableArray array];
    NSArray *so = sorted(oldPool), *sn = sorted(newPool);
    for (int i = 0; i < (int)so.count && i < 35; i++) {
        ADXEntry *e = so[i];
        e.rank = i + 1;
        [oldTop addObject:e];
        res.oldSum += e.rating;
    }
    for (int i = 0; i < (int)sn.count && i < 15; i++) {
        ADXEntry *e = sn[i];
        e.rank = i + 1;
        [newTop addObject:e];
        res.newSum += e.rating;
    }

    res.oldList = oldTop;
    res.recentList = newTop;
    res.unmatched = unmatched;
    return res;
}

@end
