//
//  CKSession.m
//  CompassKit
//
//  Created by syosan on 2017/3/5.
//  Copyright © 2017年 Keeping. All rights reserved.
//

#import "CKSessionResponse.h"
#import "CKSessionTask.h"
#import "CKUtil.h"

extern BOOL       CKConfigurationIgnoreServerTrust;
@interface CKSessionResponse ()
@property (nullable, strong, nonatomic) NSMutableDictionary<NSString*,id <CKSessionResponseDelegate> > *delegates;
@end

@implementation CKSessionResponse

- (instancetype)init
{
    self = [super init];
    if (self) {
        _delegates = [NSMutableDictionary<NSString*,id <CKSessionResponseDelegate> > dictionary];
    }
    return self;
}

+ (CKSessionResponse *)get {
    static CKSessionResponse *sessionResponse = nil;
    static dispatch_once_t sessionResponseToken;
    dispatch_once(&sessionResponseToken, ^{
        sessionResponse = [[CKSessionResponse alloc] init];
    });
    return sessionResponse;
}

+ (void)add:(id<CKSessionResponseDelegate> _Nullable)delegate {
    if (delegate) {
        @autoreleasepool {
            CKSessionTask *task = (CKSessionTask *)delegate;
            if (task.sessionTaskPtr && ![[CKSessionResponse get].delegates objectForKey:task.sessionTaskPtr]){
                [[CKSessionResponse get].delegates setObject:delegate forKey:task.sessionTaskPtr];
            }
        }
    }
}

+ (void)remove:(id<CKSessionResponseDelegate> _Nullable)delegate {
    if (delegate) {
        @autoreleasepool {
            CKSessionTask *task = (CKSessionTask *)delegate;
            if (task.sessionTaskPtr){
                [[CKSessionResponse get].delegates removeObjectForKey:task.sessionTaskPtr];
            }
        }
    }
}

#pragma mark - NSURLSessionTaskDelegate

#define ENABLE_IGNORE_TRUST 1
// 0.请求的https证书验证
//- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {
//
//    if (!challenge) { return; }
//    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
//    NSURLCredential *credential = nil;
//    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
//#if ENABLE_IGNORE_TRUST
//        SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
//        NSMutableArray *policies = [NSMutableArray array];
//        [policies addObject:(__bridge_transfer id)SecPolicyCreateBasicX509()];
//        SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);
//
//        disposition = NSURLSessionAuthChallengeUseCredential;
//        credential = [NSURLCredential credentialForTrust:serverTrust];
//#else
//        disposition = NSURLSessionAuthChallengeUseCredential;
//        credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
//#endif
//    } else {
//        disposition = NSURLSessionAuthChallengePerformDefaultHandling;
//    }
//    // 对于其他的challenges直接使用默认的验证方案
//    completionHandler(disposition,credential);
//}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {
    if (!challenge) { return; }
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    NSURLCredential *credential = nil;
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if (CKConfigurationIgnoreServerTrust) {
            SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
            NSMutableArray *policies = [NSMutableArray array];
            [policies addObject:(__bridge_transfer id)SecPolicyCreateBasicX509()];
            SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);
            
            disposition = NSURLSessionAuthChallengeUseCredential;
            credential = [NSURLCredential credentialForTrust:serverTrust];
        }
        else {
            NSString *host = [task.currentRequest.allHTTPHeaderFields objectForKey:@"Host"];
            BOOL trust = [self evaluateServerTrust:challenge.protectionSpace.serverTrust forDomain:host];
            if (!host || trust) {
                disposition = NSURLSessionAuthChallengeUseCredential;
                credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            } else {
                disposition = NSURLSessionAuthChallengePerformDefaultHandling;
            }
        }
    } else {
        disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    }
    // 对于其他的challenges直接使用默认的验证方案
    completionHandler(disposition,credential);
}

// 1.接收到服务器的响应
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    // 允许处理服务器的响应，才会继续接收服务器返回的数据
    completionHandler(NSURLSessionResponseAllow);
}

// 2.接收到服务器的数据（可能调用多次）
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    
    @autoreleasepool {
        long long ptr = (long long)dataTask;
        NSString *key = [NSString stringWithFormat:@"%lld",ptr];
        __weak typeof(id <CKSessionResponseDelegate>) _delegate = [_delegates objectForKey:key];
        if (_delegate && [_delegate respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
            [_delegate URLSession:session dataTask:dataTask didReceiveData:data];
        }
    }
}

// 3.请求成功或者失败（如果失败，error有值）
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {

    @autoreleasepool {
        long long ptr = (long long)task;
        NSString *key = [NSString stringWithFormat:@"%lld",ptr];
        __weak typeof(id <CKSessionResponseDelegate>) _delegate = [_delegates objectForKey:key];
        if (_delegate && [_delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
            [_delegate URLSession:session task:task didCompleteWithError:error];
        }
    }
}

// 4.302跳转
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * __nullable))completionHandler{
    @autoreleasepool {
        NSMutableURLRequest *newRequrst = [request mutableCopy];
        if (request.URL && request.URL.host && ![CKUtil isIPAddress:request.URL.host]) {
            [newRequrst setValue:request.URL.host forHTTPHeaderField:@"Host"];
        } else {
            [newRequrst setValue:NULL forHTTPHeaderField:@"Host"];
        }
        completionHandler(newRequrst);
    }
}

#pragma mark - EvaluateServerTrust

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust
                  forDomain:(NSString *)domain
{
    /*
     * 创建证书校验策略
     */
    NSMutableArray *policies = [NSMutableArray array];
    if (domain) {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateSSL(true, (__bridge CFStringRef)domain)];
    } else {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateBasicX509()];
    }
    /*
     * 绑定校验策略到服务端的证书上
     */
    SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);
    /*
     * 评估当前serverTrust是否可信任，
     * 官方建议在result = kSecTrustResultUnspecified 或 kSecTrustResultProceed
     * 的情况下serverTrust可以被验证通过，https://developer.apple.com/library/ios/technotes/tn2232/_index.html
     * 关于SecTrustResultType的详细信息请参考SecTrust.h
     */
    SecTrustResultType result;
    SecTrustEvaluate(serverTrust, &result);
    /*
     * 由于日志服关于https验证可能存在配置不靠谱的问题，现在增加
     * kSecTrustResultRecoverableTrustFailure的情况可被验证通过
     */
    return (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed);
}


@end
