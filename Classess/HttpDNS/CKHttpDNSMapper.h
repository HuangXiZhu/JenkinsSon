//
//  CKHttpDNSMapper.h
//  PharosSDK
//
//  Created by syosan on 2016/10/28.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CKHttpDNSMapper : NSObject
/**
 * mapping属于异步操作，如需等待，请在调用发起的地方做同步
 * host 需要做httpDNS解析的主机域名，格式如：baidu.com
 * section 会透传回来，在并发时，可以根据这个值判断是发起源，需要设置>=0，小于0将收不到回调
 * key 会透传回来，在并发时，可以根据这个值做校验
 * result 包含解析到的ip中随机的一个，以及透传回来的key，section。需要查询ip列表，可使用：+ (NSArray * _Nonnull)getHiJackIpsForHost:(NSString * _Nonnull)host
 */
+ (void)mapping:(NSString * _Nonnull)host section:(NSUInteger)idx key:(NSString *_Nonnull)key result:(void (^ __nullable)(NSString* __nullable ip, NSString* __nullable key, NSUInteger section))block;

+ (NSString * _Nonnull)getRealIpForHost:(NSString * _Nonnull)host;
+ (NSArray * _Nonnull)getHiJackIpsForHost:(NSString * _Nonnull)host;
+ (NSUInteger)getHiJackIpsCountForHost:(NSString * _Nonnull)host;
+ (void)removeHiJackIp:(NSString *_Nonnull)ip forHost:(NSString *_Nonnull)host;
+ (void)setArea:(int)area;
@end
