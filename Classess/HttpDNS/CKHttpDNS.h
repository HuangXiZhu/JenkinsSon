//
//  CKHttpDNS.h
//  PharosSDK
//
//  Created by syosan on 16/4/29.
//  Copyright © 2016年 Syosan Zung. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^CKHttpDNSActionBlock)(id _Nonnull response, NSString * _Nonnull host);

@class CKHttpDNSResult;

@interface CKHttpDNS : NSObject
#pragma mark - require
+ (void)getHttpDNS:(NSString * _Nonnull)domain block:(_Nonnull CKHttpDNSActionBlock)block;
#pragma mark - Optional
+ (void)setArea:(int)area;
+ (BOOL)isIPAddress:(NSString * _Nonnull)ipaddr;
@end

@interface CKHttpDNSResult : NSObject
+ (NSArray * _Nonnull)parseJSON:(NSData * _Nonnull)jsonData forHost:(NSString *_Nonnull)host;
@property (nonatomic,strong,nonnull)NSString *ip;
@property (nonatomic,strong,nonnull)NSString *ttl;
@property (nonatomic,strong,nonnull)NSString *desc;
@property (nonatomic,assign) NSTimeInterval cacheTime;
@end
