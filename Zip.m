// Zip.m
#import "Zip.h"
#import <zlib.h>
#import <CoreFoundation/CoreFoundation.h>

static uint16_t ZipRd16(const uint8_t *p) { return (uint16_t)(p[0] | (p[1] << 8)); }
static uint32_t ZipRd32(const uint8_t *p)
{
    return (uint32_t)(p[0] | (p[1] << 8) | (p[2] << 16) | ((uint32_t)p[3] << 24));
}

static NSString *ZipName(const uint8_t *p, NSUInteger len, BOOL utf8Flag)
{
    NSData *d = [NSData dataWithBytes:p length:len];
    NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    if (!s && !utf8Flag) {
        CFStringEncoding gbk = CFStringConvertWindowsCodepageToEncoding(936);
        if (gbk != kCFStringEncodingInvalidId)
            s = [[NSString alloc] initWithData:d encoding:CFStringConvertEncodingToNSStringEncoding(gbk)];
    }
    if (!s) s = [[NSString alloc] initWithData:d encoding:NSISOLatin1StringEncoding];
    return s ?: @"";
}

static BOOL ZipInflateToFile(const uint8_t *src, NSUInteger srcLen, NSString *outPath)
{
    z_stream zs;
    memset(&zs, 0, sizeof(zs));
    if (inflateInit2(&zs, -15) != Z_OK) return NO;

    FILE *fp = fopen(outPath.fileSystemRepresentation, "wb");
    if (!fp) { inflateEnd(&zs); return NO; }

    zs.next_in = (Bytef *)src;
    zs.avail_in = (uInt)srcLen;

    uint8_t buf[65536];
    int ret = Z_OK;
    BOOL ok = NO;
    while (1) {
        zs.next_out = buf;
        zs.avail_out = sizeof(buf);
        ret = inflate(&zs, Z_NO_FLUSH);
        if (ret != Z_OK && ret != Z_STREAM_END) break;
        size_t have = sizeof(buf) - zs.avail_out;
        if (have && fwrite(buf, 1, have, fp) != have) break;
        if (ret == Z_STREAM_END) { ok = YES; break; }
        if (zs.avail_in == 0 && have == 0) break;
    }
    fclose(fp);
    inflateEnd(&zs);
    return ok;
}

@implementation ADXZip

+ (NSString *)importZip:(NSString *)zipPath into:(NSString *)parentDir error:(NSError **)error
{
    NSData *data = [NSData dataWithContentsOfFile:zipPath options:NSDataReadingMappedIfSafe error:error];
    if (!data) return nil;
    const uint8_t *b = (const uint8_t *)data.bytes;
    NSUInteger n = data.length;
    if (n < 22) {
        if (error) *error = [NSError errorWithDomain:@"ADXZip" code:1 userInfo:@{NSLocalizedDescriptionKey: @"文件太小，不是 zip"}];
        return nil;
    }

    // 找 EOCD
    NSInteger eocd = -1;
    NSInteger lower = (NSInteger)n - 22;
    NSInteger stop = (NSInteger)n - 65557;
    if (stop < 0) stop = 0;
    for (NSInteger i = lower; i >= stop; i--) {
        if (ZipRd32(b + i) == 0x06054b50) { eocd = i; break; }
    }
    if (eocd < 0) {
        if (error) *error = [NSError errorWithDomain:@"ADXZip" code:2 userInfo:@{NSLocalizedDescriptionKey: @"找不到 zip 目录结尾（文件可能损坏）"}];
        return nil;
    }

    uint16_t count = ZipRd16(b + eocd + 10);
    uint32_t cdOffset = ZipRd32(b + eocd + 16);
    if (cdOffset >= n || count == 0) {
        if (error) *error = [NSError errorWithDomain:@"ADXZip" code:3 userInfo:@{NSLocalizedDescriptionKey: @"zip 目录为空"}];
        return nil;
    }

    // 第一遍：读中央目录，收集条目
    NSMutableArray *names = [NSMutableArray array];
    NSMutableArray *entries = [NSMutableArray array];
    NSUInteger p = cdOffset;
    for (int i = 0; i < count; i++) {
        if (p + 46 > n || ZipRd32(b + p) != 0x02014b50) break;
        uint16_t flags = ZipRd16(b + p + 8);
        uint16_t method = ZipRd16(b + p + 10);
        uint32_t csize = ZipRd32(b + p + 20);
        uint32_t lho = ZipRd32(b + p + 42);
        uint16_t nameLen = ZipRd16(b + p + 28);
        uint16_t extraLen = ZipRd16(b + p + 30);
        uint16_t commentLen = ZipRd16(b + p + 32);

        NSString *name = ZipName(b + p + 46, nameLen, (flags & 0x0800) != 0);
        if (name.length == 0) break;
        if ([name containsString:@".."] || [name hasPrefix:@"/"]) {
            if (error) *error = [NSError errorWithDomain:@"ADXZip" code:4 userInfo:@{NSLocalizedDescriptionKey: @"zip 里有可疑路径，已中止"}];
            return nil;
        }
        [names addObject:name];
        [entries addObject:@[@(method), @(csize), @(lho), @(flags)]];
        p += 46 + nameLen + extraLen + commentLen;
    }
    if (entries.count == 0) {
        if (error) *error = [NSError errorWithDomain:@"ADXZip" code:5 userInfo:@{NSLocalizedDescriptionKey: @"zip 里没有可用条目"}];
        return nil;
    }

    // 计算“唯一顶层目录”
    NSString *prefix = nil;
    NSString *first = nil;
    BOOL single = YES;
    for (NSString *name in names) {
        NSRange slash = [name rangeOfString:@"/"];
        if (slash.location == NSNotFound) { single = NO; break; }
        NSString *top = [name substringToIndex:slash.location + 1];
        if (!first) first = top;
        else if (![top isEqualToString:first]) { single = NO; break; }
    }
    if (single && first.length > 1) prefix = first;

    NSString *folderName = prefix ? [prefix substringToIndex:prefix.length - 1]
                                  : [[zipPath lastPathComponent] stringByDeletingPathExtension];
    if (folderName.length == 0) folderName = @"imported";

    NSString *dest = [parentDir stringByAppendingPathComponent:folderName];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *mkErr = nil;
    if (![fm createDirectoryAtPath:dest withIntermediateDirectories:YES attributes:nil error:&mkErr]) {
        if (error) *error = mkErr;
        return nil;
    }

    // 第二遍：真正解压
    for (NSUInteger i = 0; i < entries.count; i++) {
        NSArray *meta = entries[i];
        uint16_t method = [meta[0] unsignedShortValue];
        uint32_t csize = [meta[1] unsignedIntValue];
        uint32_t lho = [meta[2] unsignedIntValue];

        NSString *name = names[i];
        if (prefix && [name hasPrefix:prefix]) name = [name substringFromIndex:prefix.length];
        if (name.length == 0) continue;

        NSString *full = [dest stringByAppendingPathComponent:name];
        if ([name hasSuffix:@"/"]) {
            [fm createDirectoryAtPath:full withIntermediateDirectories:YES attributes:nil error:nil];
            continue;
        }
        [fm createDirectoryAtPath:[full stringByDeletingLastPathComponent]
      withIntermediateDirectories:YES attributes:nil error:nil];

        if (lho + 30 > n) continue;
        uint16_t nameLen = ZipRd16(b + lho + 26);
        uint16_t extraLen = ZipRd16(b + lho + 28);
        NSUInteger dataOff = lho + 30 + nameLen + extraLen;
        if (dataOff + csize > n) continue;

        if (method == 0) {
            [[NSData dataWithBytes:(b + dataOff) length:csize] writeToFile:full atomically:NO];
        } else if (method == 8) {
            ZipInflateToFile(b + dataOff, csize, full);
        }
        // 其他压缩方式（bzip2/lzma）极少见，跳过
    }

    return dest;
}

#pragma mark - 谱包（zip 里套 zip）

/// 目录重名时加 (2)、(3)…
static NSString *ZipUniqueDir(NSString *parent, NSString *name)
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dest = [parent stringByAppendingPathComponent:name];
    int i = 2;
    while ([fm fileExistsAtPath:dest]) {
        dest = [parent stringByAppendingPathComponent:
                [NSString stringWithFormat:@"%@ (%d)", name, i++]];
    }
    return dest;
}

/// 递归找出 dir 下所有 .zip
static NSArray *ZipFindInner(NSString *dir)
{
    NSMutableArray *out = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *en = [fm enumeratorAtPath:dir];
    for (NSString *rel in en) {
        if ([[rel pathExtension].lowercaseString isEqualToString:@"zip"]) {
            [out addObject:[dir stringByAppendingPathComponent:rel]];
        }
    }
    return out;
}

+ (NSArray *)importPack:(NSString *)zipPath into:(NSString *)parentDir error:(NSError **)error
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;

    // 先解到临时目录，看看里面是「谱面本体」还是「一包谱面」
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                     [@"ADXImport-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    [fm createDirectoryAtPath:tmp withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *outer = [self importZip:zipPath into:tmp error:error];
    if (!outer) {
        [fm removeItemAtPath:tmp error:nil];
        return nil;
    }

    NSArray *inner = ZipFindInner(outer);

    // 情况一：就是个普通谱面 / 皮肤
    if (inner.count == 0) {
        NSString *dest = ZipUniqueDir(parentDir, outer.lastPathComponent);
        if (![fm moveItemAtPath:outer toPath:dest error:&err]) {
            if (error) *error = err;
            [fm removeItemAtPath:tmp error:nil];
            return nil;
        }
        [fm removeItemAtPath:tmp error:nil];
        return @[dest];
    }

    // 情况二：谱包，逐个内层 zip 展开
    NSMutableArray *made = [NSMutableArray array];
    NSError *lastErr = nil;

    for (NSString *innerZip in inner) {
        NSString *sub = [tmp stringByAppendingPathComponent:
                         [@"x-" stringByAppendingString:NSUUID.UUID.UUIDString]];
        [fm createDirectoryAtPath:sub withIntermediateDirectories:YES attributes:nil error:nil];

        NSError *e = nil;
        NSString *dir = [self importZip:innerZip into:sub error:&e];
        if (!dir) {
            lastErr = e;
            continue;
        }

        NSString *dest = ZipUniqueDir(parentDir, dir.lastPathComponent);
        if ([fm moveItemAtPath:dir toPath:dest error:&e]) {
            [made addObject:dest];
        } else {
            lastErr = e;
        }
    }

    [fm removeItemAtPath:tmp error:nil];

    if (made.count == 0) {
        if (error) *error = lastErr ?: [NSError errorWithDomain:@"ADXZip" code:20
                                                       userInfo:@{NSLocalizedDescriptionKey:
                                                                  @"谱包里没有能解压的谱面"}];
        return nil;
    }
    return made;
}

@end
