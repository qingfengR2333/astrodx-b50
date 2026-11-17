// MajData.m — majdata.net（自制谱）数据接口
#import "MajData.h"
#import "Zip.h"

static NSString * const kMajBase = @"https://majdata.net/api3/api";

@implementation ADXMajData

#pragma mark - 基础请求

+ (void)getJSON:(NSString *)url completion:(void (^)(id obj, NSError *error))completion
{
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setTimeoutInterval:20];

    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            if (err) {
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                return;
            }
            NSInteger code = [resp isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)resp statusCode] : 0;
            if (code < 200 || code >= 300 || data.length == 0) {
                NSError *e = [NSError errorWithDomain:@"ADXMaj" code:code
                                             userInfo:@{NSLocalizedDescriptionKey: @"服务器没有返回数据"}];
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, e); });
                return;
            }
            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(obj, nil); });
        }];
    [t resume];
}

+ (NSString *)esc:(NSString *)s
{
    NSCharacterSet *keep = [NSCharacterSet URLQueryAllowedCharacterSet];
    return [s stringByAddingPercentEncodingWithAllowedCharacters:keep] ?: @"";
}

#pragma mark - 列表 / 榜单 / 详情

+ (void)listWithSearch:(NSString *)keyword
                  sort:(NSString *)sort
                completion:(void (^)(NSArray *items, NSError *error))completion
{
    NSString *url = [NSString stringWithFormat:@"%@/maichart/list?sort=%@&page=0&search=%@",
                     kMajBase, [self esc:(sort ?: @"")], [self esc:(keyword ?: @"")]];

    [self getJSON:url completion:^(id obj, NSError *err) {
        if (![obj isKindOfClass:[NSArray class]]) {
            if (completion) completion(@[], err);
            return;
        }
        if (completion) completion(obj, nil);
    }];
}

+ (void)rankingWithSort:(NSString *)sort
             completion:(void (^)(NSArray *items, NSError *error))completion
{
    NSString *url = [NSString stringWithFormat:@"%@/maichart/list?isRanking=true&sort=%@",
                     kMajBase, [self esc:(sort ?: @"hotp")]];

    [self getJSON:url completion:^(id obj, NSError *err) {
        if (![obj isKindOfClass:[NSArray class]]) {
            if (completion) completion(@[], err);
            return;
        }
        if (completion) completion(obj, nil);
    }];
}

+ (void)summaryOf:(NSString *)chartId
       completion:(void (^)(NSDictionary *info, NSError *error))completion
{
    if (!chartId.length) {
        if (completion) completion(nil, nil);
        return;
    }
    NSString *url = [NSString stringWithFormat:@"%@/maichart/%@/summary", kMajBase, chartId];

    [self getJSON:url completion:^(id obj, NSError *err) {
        if (![obj isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(nil, err);
            return;
        }
        if (completion) completion(obj, nil);
    }];
}

+ (NSString *)imageURLOf:(NSString *)chartId
{
    if (!chartId.length) return nil;
    return [NSString stringWithFormat:@"%@/maichart/%@/image?fullImage=true", kMajBase, chartId];
}

#pragma mark - 展示辅助

+ (NSArray *)levelTextsOf:(NSDictionary *)item
{
    NSArray *lv = item[@"levels"];
    if (![lv isKindOfClass:[NSArray class]]) lv = @[];

    // 槽位：0 EASY、1 BASIC、2 ADVANCED、3 EXPERT、4 MASTER、5 Re:MASTER、6 宴
    NSArray *names = @[@"EASY", @"BASIC", @"ADVANCED", @"EXPERT", @"MASTER", @"Re:MASTER", @"宴会場"];

    NSMutableArray *out = [NSMutableArray array];
    for (NSInteger i = 0; i < names.count && i < (NSInteger)lv.count; i++) {
        NSString *v = lv[i];
        if (![v isKindOfClass:[NSString class]] || v.length == 0) continue;
        [out addObject:@{@"name": names[i], @"value": v, @"slot": @(i)}];
    }
    return out;
}

+ (NSString *)subtitleOf:(NSDictionary *)item
{
    NSString *up = item[@"uploader"];
    if (![up isKindOfClass:[NSString class]]) up = @"";
    return [NSString stringWithFormat:@"%@", up];
}

#pragma mark - 下载

+ (void)getData:(NSString *)url completion:(void (^)(NSData *data, NSError *error))completion
{
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [req setTimeoutInterval:30];

    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            NSInteger code = [resp isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)resp statusCode] : 0;
            if (err || code < 200 || code >= 300 || data.length == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(nil, err ?: [NSError errorWithDomain:@"ADXMaj" code:code
                        userInfo:@{NSLocalizedDescriptionKey: @"下载失败"}]);
                });
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(data, nil); });
        }];
    [t resume];
}

+ (NSData *)syncData:(NSString *)url timeout:(NSTimeInterval)timeout
{
    __block NSData *out = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [req setValue:@"https://majdata.net/" forHTTPHeaderField:@"Referer"];
    [req setTimeoutInterval:timeout];

    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            if (!err && data.length > 0) out = data;
            dispatch_semaphore_signal(sem);
        }];
    [t resume];

    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout + 6) * NSEC_PER_SEC)));
    return out;
}

+ (void)download:(NSDictionary *)item
      includeBGA:(BOOL)includeBGA
        progress:(void (^)(CGFloat ratio, NSString *status))progress
      completion:(void (^)(NSString *folder, NSError *error))completion
{
    NSString *cid = item[@"id"];
    NSString *title = item[@"title"] ?: @"自制谱";
    if (![cid isKindOfClass:[NSString class]] || !cid.length) {
        if (completion) completion(nil, [NSError errorWithDomain:@"ADXMaj" code:-1
            userInfo:@{NSLocalizedDescriptionKey: @"谱面编号缺失"}]);
        return;
    }

    NSCharacterSet *bad = [NSCharacterSet characterSetWithCharactersInString:@"/\\:*?\"<>|"];
    NSString *safe = [[title componentsSeparatedByCharactersInSet:bad] componentsJoinedByString:@"_"];
    safe = [safe stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!safe.length) safe = @"自制谱";

    NSString *levels = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/levels"];
    [[NSFileManager defaultManager] createDirectoryAtPath:levels withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *folder = [levels stringByAppendingPathComponent:safe];
    NSInteger n = 2;
    while ([[NSFileManager defaultManager] fileExistsAtPath:folder]) {
        folder = [levels stringByAppendingPathComponent:
                  [NSString stringWithFormat:@"%@ (%ld)", safe, (long)n++]];
    }

    if (![[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES error:nil]) {
        if (completion) completion(nil, [NSError errorWithDomain:@"ADXMaj" code:-2
            userInfo:@{NSLocalizedDescriptionKey: @"无法创建文件夹"}]);
        return;
    }

    NSString *base = [NSString stringWithFormat:@"%@/maichart/%@", kMajBase, cid];

    NSMutableArray *steps = [NSMutableArray array];
    [steps addObject:@{@"url": [base stringByAppendingString:@"/chart?intent=download"], @"file": @"maidata.txt", @"name": @"谱面", @"need": @YES}];
    [steps addObject:@{@"url": [base stringByAppendingString:@"/track"], @"file": @"track.mp3", @"name": @"音频", @"need": @NO}];
    [steps addObject:@{@"url": [self imageURLOf:cid], @"file": @"bg.png", @"name": @"曲绘", @"need": @NO}];
    if (includeBGA) {
        [steps addObject:@{@"url": [base stringByAppendingString:@"/video"], @"file": @"bg.mp4", @"name": @"BGA", @"need": @NO}];
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSInteger total = (NSInteger)steps.count;
        BOOL failed = NO;

        for (NSInteger i = 0; i < total; i++) {
            NSDictionary *st = steps[i];
            BOOL need = [st[@"need"] boolValue];
            NSString *name = st[@"name"];

            if (progress) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progress((CGFloat)i / (CGFloat)total,
                             [NSString stringWithFormat:@"正在下载 %@…（%ld/%ld）", name, (long)(i + 1), (long)total]);
                });
            }

            NSData *data = [self syncData:st[@"url"] timeout:30];
            if (!data.length) {
                if (need) { failed = YES; break; }
                continue;
            }

            NSString *path = [folder stringByAppendingPathComponent:st[@"file"]];
            [data writeToFile:path atomically:YES];
        }

        if (failed) {
            [[NSFileManager defaultManager] removeItemAtPath:folder error:nil];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                if (failed) {
                    completion(nil, [NSError errorWithDomain:@"ADXMaj" code:-3
                        userInfo:@{NSLocalizedDescriptionKey: @"下载失败，请重试"}]);
                } else {
                    completion([folder lastPathComponent], nil);
                }
            }
        });
    });
}

@end
