//
//  CKSessionConfiguration.m
//  CompassKit
//
//  Created by syosan on 2016/12/16.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#import "CKSessionConfiguration.h"

@implementation CKSessionConfiguration

+ (NSURLSessionConfiguration *)get
{
    static NSURLSessionConfiguration *downloadConfig = nil;
    static dispatch_once_t downloadConfigToken;
    dispatch_once(&downloadConfigToken, ^{
        downloadConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        downloadConfig.discretionary = YES;
        downloadConfig.HTTPShouldSetCookies = YES;
        downloadConfig.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
        downloadConfig.HTTPShouldUsePipelining = YES;
        downloadConfig.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
        /*
         * downloadConfig.timeoutIntervalForRequest = 30;
         * 给request指定每次接收数据超时间隔，如果下一次接受新数据用时超过该值，则发送一个请求超时给该request。默认为60s
         */
        downloadConfig.timeoutIntervalForRequest = 5;
    });
    return downloadConfig;
}

+ (NSURLSessionConfiguration *)getWithIdentifier:(NSString *)identifier
{
    NSURLSessionConfiguration *downloadConfig = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
    downloadConfig.discretionary = YES;
    downloadConfig.HTTPShouldSetCookies = YES;
    downloadConfig.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
    downloadConfig.HTTPShouldUsePipelining = YES;
    downloadConfig.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
    downloadConfig.timeoutIntervalForRequest = 5;
    return downloadConfig;
}

@end
