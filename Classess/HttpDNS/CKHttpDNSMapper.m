//
//  CKHttpDNSMapper.m
//  PharosSDK
//
//  Created by syosan on 2016/10/28.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#import "CKHttpDNSMapper.h"
#import "CKHttpDNS.h"

typedef void (^CKHttpDNSMapperResultBlock)(NSString* url, NSString* key, NSUInteger section);

@interface CKHttpDNSMapper ()
@property (assign, nonatomic) BOOL querying;
@property (nullable, strong, nonatomic) NSMutableArray *queue;
@property (nullable, strong, nonatomic) NSMutableDictionary *response;
@property (nullable, strong, nonatomic) NSString *running;
@end

#define CKHttpDNS_MAPPER [CKHttpDNSMapper shareInstance]

@implementation CKHttpDNSMapper

+ (CKHttpDNSMapper *)shareInstance
{
    static CKHttpDNSMapper *downloadCache = nil;
    static dispatch_once_t downloadCacheToken;
    dispatch_once(&downloadCacheToken, ^{
        downloadCache = [[CKHttpDNSMapper alloc] init];
    });
    
    return downloadCache;
}

- (void)dealloc
{
    [_queue removeAllObjects];
    [_response removeAllObjects];
    _queue = nil;
    _response = nil;
    _running = nil;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _queue = [NSMutableArray array];
        _response = [NSMutableDictionary dictionary];
        _running = @"runing";
    }
    return self;
}

- (void)addDNSToQueue:(NSDictionary*)DNS
{
    [_queue addObject:DNS];
    [self performSelector:@selector(sendHttpDNSQueryByQueue) onThread:[CKHttpDNSMapper httpDNSThread] withObject:NULL waitUntilDone:NO modes:@[NSDefaultRunLoopMode]];
}

- (void)sendHttpDNSQueryByQueue
{
    if ([_queue count] < 1) { _querying = NO; return; }
    if (_querying) { return; }
    _querying = YES;
    
    NSDictionary *DNS   = [_queue objectAtIndex:0];
    NSString *httpHost  = [DNS objectForKey:@"Host"];
    NSString *httpKey   = [DNS objectForKey:@"Key"];
    NSInteger section   = [[DNS objectForKey:@"Section"] integerValue];
    __block CKHttpDNSMapperResultBlock mapperBlock = [DNS objectForKey:@"block"];
    [_queue removeObjectAtIndex:0];
    
    NSArray *result = [_response objectForKey:httpHost];
    if (result && [result count] == 0 && section > -1) {
        /* 解析过，无ip地址，直接返回 */
        if (mapperBlock) {
            mapperBlock(@"NotHost",httpKey,section);
            mapperBlock = NULL;
        }
        _querying = NO;
        [self performSelector:@selector(sendHttpDNSQueryByQueue) onThread:[CKHttpDNSMapper httpDNSThread] withObject:NULL waitUntilDone:NO modes:@[NSDefaultRunLoopMode]];
        return;
    } else if (result && [result count] > 0 && section > -1) {
        /* 解析过，有ip地址，直接返回 */
        if (mapperBlock) {
            NSString *result = [self parseSimpleHttpDNS:httpHost];
            mapperBlock(result,httpKey,section);
            mapperBlock = NULL;
        }
        _querying = NO;
        [self performSelector:@selector(sendHttpDNSQueryByQueue) onThread:[CKHttpDNSMapper httpDNSThread] withObject:NULL waitUntilDone:NO modes:@[NSDefaultRunLoopMode]];
        return;
    }
    
    /* 执行HttpDNS解析 */
    [CKHttpDNS getHttpDNS:httpHost block:^(id response, NSString *httpHost) {
        if ([response isKindOfClass:[NSArray class]]) {
            // cache it.
            [_response setObject:response forKey:httpHost];
            if (mapperBlock && section > -1) {
                NSString *result = [self parseSimpleHttpDNS:httpHost];
                mapperBlock(result,httpKey,section);
                mapperBlock = NULL;
            }
        }
        _querying = NO;
        [self performSelector:@selector(sendHttpDNSQueryByQueue) onThread:[CKHttpDNSMapper httpDNSThread] withObject:NULL waitUntilDone:NO modes:@[NSDefaultRunLoopMode]];
    }];
}

- (NSString*)parseSimpleHttpDNS:(NSString *)httpHost
{
    NSArray *results = [_response objectForKey:httpHost];
    if (!results || [results count] == 0) {
        return @"NotHost";
    } else {
        /* 从已经解析的ip列表中随机选择一个 */
        srand((unsigned)time(0));
        NSUInteger currentIdx = arc4random() % [results count];
        NSString *ip = [results objectAtIndex:currentIdx];
        return ip;
    }
}

#pragma mark - Public APIs

+ (void)setArea:(int)area
{
    [CKHttpDNS setArea:area];
}

+ (NSString*)getRealIpForHost:(NSString*)host
{
    @synchronized (CKHttpDNS_MAPPER.running) {
        if (!host) { return @"NotHost"; }
        NSString *ipaddr = [CKHttpDNS_MAPPER parseSimpleHttpDNS:host];
        if ([@"NotHost" isEqualToString:ipaddr]) {
            return host;
        }
        return ipaddr;
    }
}

+ (void)removeHiJackIp:(NSString *_Nonnull)ip forHost:(NSString *_Nonnull)host
{
    @synchronized (CKHttpDNS_MAPPER.running) {
        if (host && [CKHttpDNS_MAPPER.response objectForKey:host]) {
            NSMutableArray *ips = [[CKHttpDNS_MAPPER.response objectForKey:host] mutableCopy];
            if (ips && [ips count] > 0) {
                [ips removeObject:ip];
                [CKHttpDNS_MAPPER.response setObject:ips forKey:host];
            }
        }
    }
}

+ (NSUInteger)getHiJackIpsCountForHost:(NSString*)host
{
    @synchronized (CKHttpDNS_MAPPER.running) {
        if (host) {
            NSArray *ips = [CKHttpDNS_MAPPER.response objectForKey:host];
            if (ips) {
                return [ips count];
            }
        }
        return 0;
    }
}

+ (NSArray*)getHiJackIpsForHost:(NSString*)host
{
    @synchronized (CKHttpDNS_MAPPER.running) {
        @autoreleasepool {
            if (host && [CKHttpDNS_MAPPER.response objectForKey:host]) {
                NSArray *ips = [CKHttpDNS_MAPPER.response objectForKey:host];
                return ips;
            }
            return @[];
        }
    }
}

+ (void)mapping:(NSString*)host section:(NSUInteger)idx key:(NSString *)key result:(void (^ __nullable)(NSString* __nullable ip,NSString* __nullable key, NSUInteger section))block
{
    
    @synchronized (CKHttpDNS_MAPPER.running) {
        
        if ([CKHttpDNS isIPAddress:host]) {
            if (block) { block(@"NotHost",key,idx); }
            return;
        }
        
        if ( [CKHttpDNS_MAPPER.response objectForKey:host] ) {
            /* 已解析过 */
            NSArray *results = [CKHttpDNS_MAPPER.response objectForKey:host];
            if ([results count] == 0) {
                if (block) { block(@"NotHost",key,idx); }
                return;
            }
            /* 随机从ip列表中选一个ip地址 */
            srand((unsigned)time(0));
            NSUInteger currentIdx = arc4random() % [results count];
            NSString *ip = [results objectAtIndex:currentIdx];
            if (block) { block(ip,key,idx); }
        } else {
            /* 该Host未解析过，通过网络请求HttpDNS解析，发起网络请求 */
            [CKHttpDNS_MAPPER addDNSToQueue:@{@"Host":host,@"Key":key,@"Section":@(idx),@"block":block}];
        }
    }
}

#pragma mark - Thread

+ (void)__attribute__((noreturn))httpNDSEntry:(id)__unused object
{
    do {
        @autoreleasepool {
            [[NSThread currentThread] setName:@"HttpDNSThread"];
            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
            [runLoop run];
        }
    } while (YES);
}

+ (NSThread *)httpDNSThread
{
    static NSThread *_networkThread = nil;
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate, ^{
        _networkThread = [[NSThread alloc] initWithTarget:self selector:@selector(httpNDSEntry:) object:nil];
        [_networkThread start];
    });
    
    return _networkThread;
}

@end
