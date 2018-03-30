//
//  CKRequstManager.m
//  CompassKit
//
//  Created by syosan on 2016/12/22.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#import "CKRequstManager.h"
#import "CKSessionManager.h"
#import "CKLog.h"
#import "CKUtil.h"
#import <UIKit/UIKit.h>

extern int        CKConfigurationArea;
@interface CKRequstManager ()
@property (nullable, strong, nonatomic) NSMutableDictionary *requstHostIp;
@property (nullable, strong, nonatomic) NSMutableDictionary *requsts;
@end

#define NGOSVersion_6_0_LESS ([[[UIDevice currentDevice] systemVersion] floatValue]< 7.0)
#define NGOSVersion_9_0_MORE ([[[UIDevice currentDevice] systemVersion] floatValue]>=9.0)
#define NGWK_REQUST_MANAGER [CKRequstManager getInst]

@implementation CKRequstManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _requstHostIp = [NSMutableDictionary dictionary];
        _requsts = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (CKRequstManager *)getInst
{
    static CKRequstManager *currentRequstManager = nil;
    static dispatch_once_t requstManagerToken;
    dispatch_once(&requstManagerToken, ^{
        currentRequstManager = [[CKRequstManager alloc] init];
    });
    return currentRequstManager;
}

+ (NSString *)getHostIp:(NSString *)host
{
    if (host && [NGWK_REQUST_MANAGER.requstHostIp objectForKey:host]) {
        return [NGWK_REQUST_MANAGER.requstHostIp objectForKey:host];
    }
    NSString *hostIp = [CKUtil getHostIp:host];
    if (hostIp) {
        [NGWK_REQUST_MANAGER.requstHostIp setObject:hostIp forKey:host];
    }
    return hostIp;
}

+ (CKRequst *)getRequst:(NSString *)url host:(NSString *)host
{
    if (!url) { return nil; }
    
    NSString *newUrl = nil;
    if (2 == CKConfigurationArea) {
        newUrl = [url stringByReplacingOccurrencesOfString:@".netease.com" withString:@".easebar.com"];
    } else {
        newUrl = url;
    }
    NSString *urlString = nil;
    if (NGOSVersion_9_0_MORE) {
        urlString = [newUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    } else {
        urlString = [newUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    if (!urlString) { return nil; }
    
    NSURL *requestUrl = [NSURL URLWithString:urlString];
    if (!requestUrl) { return nil; }
    
    CKRequst* request = [CKRequst requestWithURL:requestUrl
                                     cachePolicy:NSURLRequestReloadIgnoringCacheData
                                 timeoutInterval:30];
    
    /*
     * 添加Host到HEADER中
     */
    if (host) {
        
        // refuse ip address For HTTPHeaderField.
        if (![CKUtil isIPAddress:host]) {
            [request setValue:host forHTTPHeaderField:@"Host"];
        }
        
        request.host = host;
        /*
         * get remote Host ipaddress
         * 域名解析(DNS)出ip会造成一定的耗时，跟网络有关
         * 目前观察到的下载过程中，停留在0.0%的卡顿就是由于DNS解析超时造成!!!!
         */
        if (![CKUtil isIPAddress:host] && [CKRequstManager getHostIp:host]) {
            request.hostIp = [CKRequstManager getHostIp:host];
        } else if ([CKUtil isIPAddress:host]) {
            request.hostIp = host;
        }
    } else if (requestUrl.host && ![CKUtil isIPAddress:requestUrl.host]) {
        [request setValue:requestUrl.host forHTTPHeaderField:@"Host"];
    }
    
    return request;
}

+ (CKRequst *)getViaURL:(NSString *)url host:(NSString *)host encoding:(BOOL)disable
{
    /*
     * 从缓存中取CKRequst，如果不存在，则新建并缓存
     */
    CKRequst* request = [CKRequstManager getRequst:url host:host];
    
    /*
     * 实测发现，ios会设置gzip的压缩，可能导致获取size出错，从而导致下载出错
     * 因此这里强制置空
     */
    if (disable) {
        [request setValue:@"" forHTTPHeaderField:@"Accept-Encoding"];
    } else {
        [request setValue:NULL forHTTPHeaderField:@"Accept-Encoding"];
    }
    
    return request;
}

@end
