//
//  CKSession.m
//  CompassKit
//
//  Created by syosan on 2016/12/18.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#import "CKSessionTask.h"
#import "CKSessionManager.h"
#import "CKSessionResponse.h"
#import "CKHttpDNSMapper.h"
#import "CKUtil.h"
#import "CKLog.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/CADisplayLink.h>

#ifndef ENABLE_USE_TIMER
#define ENABLE_USE_TIMER ([[[UIDevice currentDevice] systemVersion] floatValue] < 10.0)
#endif

typedef void(^CKSessionResponseDataHandler)(NSData * _Nullable data);
typedef NSURLRequest * _Nullable(^CKSessionResponseHiJackHandler)(NSURLRequest * _Nullable newRequest);
typedef void(^CKSessionResponseCompletionHandler)(NSURLResponse * _Nullable response, NSError * _Nullable error);

extern int        CKConfigurationArea;
extern BOOL       CKConfigurationIgnoreServerTrust;
@interface CKSessionTask () <CKSessionResponseDelegate>
@property (nonnull,  strong, nonatomic) NSTimer *sessionTimer;
@property (nonnull,  strong, nonatomic) CADisplayLink *sessionDisplayLink;
@property (nullable, weak  , nonatomic) NSURLSession *session;
@property (nonnull,  strong, nonatomic) NSURLSessionDataTask *task;
@property (nonnull,  strong, nonatomic) CKSessionResponseDataHandler sessionReceiveData;
@property (nonnull,  strong, nonatomic) CKSessionResponseHiJackHandler sessionHiJackHandler;
@property (nonnull,  strong, nonatomic) CKSessionResponseCompletionHandler sessionCompletionHandler;
@end

@implementation CKSessionTask

- (void)dealloc {
    _sessionTaskPtr = nil;
    _task = nil;
    _session = nil;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sessionIgnoreCerTrust = NO;
        _sessionPerformingArea = 0;
    }
    return self;
}

- (void)setSessionPerformingArea:(int)sessionPerformingArea {
    _sessionPerformingArea = sessionPerformingArea;
    CKConfigurationArea = sessionPerformingArea;
}

- (void)dataTaskRequst:(nonnull CKRequst *)request didReceiveData:(void (^ _Nullable)(NSData * _Nullable data))recvData hiJackHandler:(NSURLRequest * _Nullable (^ _Nullable)(NSURLRequest * _Nullable newRequest))hiJackHandler completionHandler:(void (^ _Nonnull)(NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
    if (!request) { return; }
    self.sessionReceiveData = recvData;
    self.sessionHiJackHandler = hiJackHandler;
    self.sessionCompletionHandler = completionHandler;
    [self dataTaskViaRequst:request];
}

- (void)dataTaskViaRequst:(CKRequst * _Nonnull)request {
    if (request) {
        CKConfigurationIgnoreServerTrust = self.sessionIgnoreCerTrust;
        self.session = [CKSessionManager sessionViaHost:request.hostIp];
        self.task = [self.session dataTaskWithRequest:request];
        long long ptr = (long long)self.task;
        _sessionTaskPtr = [NSString stringWithFormat:@"%lld",ptr];
        [CKSessionResponse add:self];
        [self.task resume];
    }
}


#pragma mark - CKSessionResponseDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    // 以下是业务处理逻辑
    if (self.sessionReceiveData) {
        self.sessionReceiveData(data);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    // 请求完成,成功或者失败的处理
    [CKSessionResponse remove:self];
    
    if (error && task.currentRequest.URL.host && ![CKUtil isIPAddress:task.currentRequest.URL.host]) {
        [self URLSession:session task:task didAntiHiJackWithError:error];
        return;
    }
    
    // 以下是业务处理逻辑
    if (self.sessionCompletionHandler) {
        self.sessionCompletionHandler(task.response,error);
    }
}


// 3.1.请求成功或者失败（如果失败，error有值，先做反劫持）
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didAntiHiJackWithError:(NSError *)error {
    @autoreleasepool {
        [CKHttpDNSMapper setArea:self.sessionPerformingArea];
        //入口
        [CKHttpDNSMapper mapping:task.currentRequest.URL.host section:1001 key:@"token" result:^(NSString * _Nullable ip, NSString * _Nullable key, NSUInteger section) {
            @autoreleasepool {
                if (1001 == section && key && [@"token" isEqualToString:key]) {
                    if ([@"NotHost" isEqualToString:ip]) {
                        // 以下是业务处理逻辑
                        if (self.sessionCompletionHandler) {
                            self.sessionCompletionHandler(task.response,error);
                        }
                    } else {
                        NSString *host   = task.currentRequest.URL.host;
                        NSString *url    = [task.currentRequest.URL.absoluteString stringByReplacingOccurrencesOfString:host withString:ip];
                        NSURL    *newURL = [NSURL URLWithString:url];
                        NSMutableURLRequest *newRequrst = [NSMutableURLRequest requestWithURL:newURL];
                        NSDictionary *headers = task.currentRequest.allHTTPHeaderFields;
                        if (headers && [headers isKindOfClass:[NSDictionary class]] && [headers count] > 0) {
                            for (NSString *key in [headers allKeys]) {
                                NSString *value = [headers objectForKey:key];
                                if (![@"host" isEqualToString:[key lowercaseString]]) {
                                    [newRequrst setValue:value forHTTPHeaderField:key];
                                }
                            }
                        }
                        if (newRequrst.URL && host && ![CKUtil isIPAddress:host]) {
                            [newRequrst setValue:host forHTTPHeaderField:@"Host"];
                        }
                        if (task.currentRequest.HTTPMethod) {
                            newRequrst.HTTPMethod = task.currentRequest.HTTPMethod;
                        }
                        CKLog(@"Host  : %@ has been HiJack, we will continue with new ip: %@", host, ip);
                        [self.task cancel];
                        self.session = [CKSessionManager sessionViaHost:ip];
                        if (self.sessionHiJackHandler) {
                            NSURLRequest *customRequest = self.sessionHiJackHandler(newRequrst);
                            if (customRequest) {
                                self.task = [self.session dataTaskWithRequest:customRequest];
                            } else {
                                self.task = [self.session dataTaskWithRequest:newRequrst];
                            }
                        } else {
                            self.task = [self.session dataTaskWithRequest:newRequrst];
                        }
                        long long ptr = (long long)self.task;
                        _sessionTaskPtr = [NSString stringWithFormat:@"%lld",ptr];
                        [CKSessionResponse add:self];
                        [self.task resume];
                    }
                }
            }
        }];
    }
}

@end
