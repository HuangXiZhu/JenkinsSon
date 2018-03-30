//
//  CKHttpDNS.m
//  PharosSDK
//
//  Created by syosan on 16/4/29.
//  Copyright © 2016年 Syosan Zung. All rights reserved.
//

#import "CKHttpDNS.h"
#import <UIKit/UIKit.h>

#define NGOSVersion_6_0_LESS ([[[UIDevice currentDevice] systemVersion] floatValue]< 7.0)
#define NGOSVersion_9_0_MORE ([[[UIDevice currentDevice] systemVersion] floatValue]>=9.0)
#define DOWN_CKHttpDNS [CKHttpDNS shareInstance]

static CKHttpDNSActionBlock theHttpDNSActionBlock;

/* DNS处理阶段 */
typedef NS_ENUM(NSInteger, CKHttpDNSHandle) {
    CKHttpDNSHandleConfiguration,
    CKHttpDNSHandleResolving,
};

//思路：step1.获取本地hardcode fallback IP,启动线程去获取新的fallback IP,如果获取成功，则更新本地fallback IP
//step2.启动DNS txt获取service IP,如果获取失败，则使用本地fallback IP作为service IP
//step2.1 fetchTXTRecords获取,返回结果类似：# httpdns ip1(十进制),httpdns ip2(十进制),(token+ip md5sum)
//                                         997165474,1778533773,3a9dd5dbcf82b01d12cca3348b2de276
//step2.2 校验MD5摘要  MD5(token,htpdns ip1,httpdns ip2) == step2.1.(token+ip md5sum) 确认token怎么设置?!文档说了，是自己申请
//step3.利用service IP 调用getHttpDNSResolving，获取域名对应的IP，实现DNS。contact杨博 HTTP请求头需要加入 AUTH-PROJECT、AUTH-TOKEN
//step3.1 请求格式为：https://httpdns ip/v2/?domain=login.netease.com




@interface CKHttpDNS () <NSURLConnectionDataDelegate>
@property (strong, nonatomic) NSMutableData *resolvedData;
@property (strong, nonatomic) NSMutableData *responseData;
@property (assign, nonatomic) CKHttpDNSHandle httpDNSHandle;
@property (strong, nonatomic) NSString *host;
@property (strong, nonatomic) NSString *configHost;
@property (strong, nonatomic) NSDictionary *configResult;
@property (strong, nonatomic) NSString *serviceIp;
@property (assign, nonatomic) int oversea;
@property (nonatomic, strong) NSURLConnection *configConnection;
@property (nonatomic, strong) NSURLConnection *resolveConnection;
@end

@implementation CKHttpDNS

- (void)dealloc {
    _responseData = nil;
    _host = nil;
    _configHost = nil;
    _configResult = nil;
    _serviceIp = nil;
    _resolvedData = nil;
}

+ (CKHttpDNS *)shareInstance
{
    static CKHttpDNS *_httpDNS = nil;
    static dispatch_once_t _httpDNSToken;
    dispatch_once(&_httpDNSToken, ^{
        _httpDNS = [[CKHttpDNS alloc] init];
    });
    
    return _httpDNS;
}

/* 通过https://mbdl.update.netease.com/httpdns.mbdl获取配置 */
+ (void)getHttpDNS:(NSString *)domain block:(CKHttpDNSActionBlock)block
{
    theHttpDNSActionBlock = block;
    dispatch_async(dispatch_get_main_queue(), ^{
        [DOWN_CKHttpDNS getHttpDNSServiceIPQuery:domain];
    });
}

- (void)getHttpDNSServiceIPQuery:(NSString *)domain
{
    if (!domain) {
        if (theHttpDNSActionBlock) {
            theHttpDNSActionBlock(@[],_host);
        }
        return;
    }
    _serviceIp = nil;
    _host = domain;
    
    if (!_configResult || [_configResult count] < 1) {
        [self getHttpDNSServiceConfigurationQuery];
        return;
    }
    
    if (_configResult && [_configResult count] > 0) {
        NSArray *serviceIps = nil;
        if ( 0 == _oversea ) {
            /* 国内或者默认设置 */
            serviceIps = [_configResult objectForKey:@"mainland"];
        } else {
            /* 海外，台湾地区 */
            serviceIps = [_configResult objectForKey:@"oversea"];
        }
        /* 获取serviceIp */
        if (serviceIps && [serviceIps count] > 0) {
            srand((unsigned)time(0));
            NSUInteger row = arc4random() % [serviceIps count];
            _serviceIp = [serviceIps objectAtIndex:row];
        }
    }
    if (!_serviceIp || [@"" isEqualToString:_serviceIp]) {
        [self getHttpDNSServiceConfigurationQuery];
    } else {
        [self getHttpDNSResolving:_host];
    }
}

- (void)getHttpDNSServiceConfigurationQuery
{
    _httpDNSHandle = CKHttpDNSHandleConfiguration;
    
    if ( 2 == _oversea ) {
        /* 设置为台湾地区 */
        _configHost = @"mbdl.update.easebar.com";
    } else {
        /* 海外，国内或者默认设置 */
        _configHost = @"mbdl.update.netease.com";
    }
    
    NSString *strURL = [NSString stringWithFormat:@"https://%@/httpdns.mbdl",_configHost];
    NSURL *reqURL = [NSURL URLWithString:strURL];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:reqURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:5.0];
    
    self.configConnection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self startImmediately:NO];
    [self.configConnection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [self.configConnection start];
}

#pragma mark-解析的作用是什么
- (void)getHttpDNSResolving:(NSString *)host
{
    _httpDNSHandle = CKHttpDNSHandleResolving;
    
    if ([_serviceIp rangeOfString:@":"].location != NSNotFound) {
        /* ipv6 */
        _serviceIp = [NSString stringWithFormat:@"[%@]",_serviceIp];
    }
    NSString *URLString = [NSString stringWithFormat:@"https://%@/v2/?domain=%@",_serviceIp,host];
    
    NSURL *reqURL = [NSURL URLWithString:URLString];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:reqURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:5.0];
    
    self.resolveConnection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self startImmediately:NO];
    [self.resolveConnection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [self.resolveConnection start];
}

#pragma mark - CKHttpDNS 解析处理逻辑

- (void)parseHttpDNSResolvingSuccessed
{
    NSArray *ips = [CKHttpDNSResult parseJSON:_responseData forHost:_host];
    if (theHttpDNSActionBlock) {
        theHttpDNSActionBlock(ips,_host);
    }
}

- (void)parseHttpDNSServiceConfiguration
{
    if (!_responseData || _responseData.length == 0) {
        if (theHttpDNSActionBlock) {
            theHttpDNSActionBlock(@[],_host);
        }
        return;
    }
    
    NSError *error = nil;
    NSData *jsonData = nil;
    if (NGOSVersion_6_0_LESS) {
        NSString *fileString = [[NSString alloc] initWithData:_responseData encoding:NSUTF8StringEncoding];
        jsonData = [[NSData alloc] initWithBase64Encoding:fileString];
    } else {
        jsonData = [[NSData alloc] initWithBase64EncodedData:_responseData options:NSDataBase64DecodingIgnoreUnknownCharacters];
    }
    
    if (!jsonData) {
        
        NSLog(@"HttpDNS配置文件格式错误，请确认。");
        
        if (theHttpDNSActionBlock) {
            theHttpDNSActionBlock(@[],_host);
        }
        return ;
    }
    
    //解析json数据，使用系统方法 JSONObjectWithData:  options: error:
    NSDictionary* JsonDic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                            options:NSJSONReadingMutableLeaves
                                                              error:&error];
    
    
    if(error || !JsonDic)
    {
        NSLog(@"HttpDNS Json Dictionary Err: %@.", [error localizedDescription]);
        
        if (theHttpDNSActionBlock) {
            theHttpDNSActionBlock(@[],_host);
        }
        return;
    }
    
    _configResult = JsonDic;
    
    if (_configResult && [_configResult count] > 0) {
        NSArray *serviceIps = nil;
        if ( 0 == _oversea ) {
            /* 国内或者默认设置 */
            serviceIps = [_configResult objectForKey:@"mainland"];
        } else {
            /* 海外，台湾地区 */
            serviceIps = [_configResult objectForKey:@"oversea"];
        }
        /* 获取serviceIp */
        if (serviceIps && [serviceIps count] > 0) {
            srand((unsigned)time(0));
            NSUInteger row = arc4random() % [serviceIps count];
            _serviceIp = [serviceIps objectAtIndex:row];
        }
    }
    if (!_serviceIp || [@"" isEqualToString:_serviceIp]) {
        if (theHttpDNSActionBlock) {
            theHttpDNSActionBlock(@[],_host);
        }
    } else {
        [self getHttpDNSResolving:_host];
    }
}

- (void)connectionDidSuccess
{
    if (CKHttpDNSHandleConfiguration == self.httpDNSHandle) {
        [self parseHttpDNSServiceConfiguration];
    }
    else if (CKHttpDNSHandleResolving == self.httpDNSHandle)
    {
        [self parseHttpDNSResolvingSuccessed];
    }
}

- (void)connectionDidFailWithError:(NSError *)error
{
    if (CKHttpDNSHandleConfiguration == self.httpDNSHandle) {
        /* 通过域名查询HttpDNS服务配置失败，改用lvsip进行查询 */
        if ( 0 == _oversea ) {
            /* 国内或者默认设置 */
            _serviceIp = @"106.2.69.141";
        } else {
            /* 海外，台湾地区 */
            _serviceIp = @"52.192.189.28";
        }
        [self getHttpDNSResolving:_host];
    }
    else if (CKHttpDNSHandleResolving == self.httpDNSHandle)
    {
        /* 通过HttpDNS解析失败，告知caller */
        if (theHttpDNSActionBlock) {
            theHttpDNSActionBlock(@[],_host);
        }
    }
}

#pragma mark - NSURLConnectionDataDelegate

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (connection == self.configConnection) {
        _responseData = [NSMutableData data];
    }else if (connection == self.resolveConnection) {
        _resolvedData  = [NSMutableData new];
    }
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (connection == self.configConnection) {
        [_responseData appendData:data];
    }else if (connection == self.resolveConnection) {
        [_resolvedData appendData:data];
    }
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (connection == self.configConnection) {
        if (!_responseData || [_responseData length] == 0) {
            [self connectionDidFailWithError:NULL];
        } else {
            [self connectionDidSuccess];
        }
    }else if (connection == self.resolveConnection) {
        if (!_resolvedData || [_resolvedData length] == 0) {
            [self connectionDidFailWithError:NULL];
        } else {
            [self connectionDidSuccess];
        }
    }
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self connectionDidFailWithError:error];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    @autoreleasepool {
        if (response) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            if (httpResponse.statusCode == 302 || httpResponse.statusCode == 301 || httpResponse.statusCode == 307 || httpResponse.statusCode == 308) {
                NSMutableURLRequest *newRequrst = [request mutableCopy];
                if (request.URL && request.URL.host && ![CKHttpDNS isIPAddress:request.URL.host]) {
                    [newRequrst setValue:request.URL.host forHTTPHeaderField:@"Host"];
                } else {
                    [newRequrst setValue:NULL forHTTPHeaderField:@"Host"];
                }
                return newRequrst;
            }
        }
        return request;
    }
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    
    @autoreleasepool {
        if (!challenge) { return; }
        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
            
            SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
            NSMutableArray *policies = [NSMutableArray array];
            [policies addObject:(__bridge_transfer id)SecPolicyCreateBasicX509()];
            SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);
            
            [challenge.sender useCredential:[NSURLCredential credentialForTrust:serverTrust] forAuthenticationChallenge:challenge];
        }
        
        [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
    }
}

#pragma mark - Util

+ (void)setArea:(int)area
{
    DOWN_CKHttpDNS.oversea = area;
}

+ (BOOL)isIPAddress:(NSString *)ipaddr
{
    @autoreleasepool {
        if (!ipaddr) {
            return NO;
        }
        // http://www.myexception.cn/program/564495.html
        NSRange iprange = [ipaddr rangeOfString:@"([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})|(((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:)))(%.+)?)" options:NSRegularExpressionSearch];
        if (iprange.location == NSNotFound) {
            return NO;
        } else {
            return YES;
        }
    }
}

@end

@implementation CKHttpDNSResult
+ (NSArray * _Nonnull)parseJSON:(NSData * _Nonnull)jsonData forHost:(NSString *)host
{
    if (!jsonData) {
        return @[];
    }
    NSError *error = nil;
    NSDictionary* JsonDic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                            options:NSJSONReadingMutableLeaves
                                                              error:&error];
    
    
    if(error || !JsonDic)
    {
        NSLog(@"Json Dictionary Err: %@.", [error localizedDescription]);
        return @[];
    }
    NSString *domain = [JsonDic objectForKey:@"domain"];
    if (!domain || ![host isEqualToString:domain]) {
        return @[];
    }
    NSArray *ips = [JsonDic objectForKey:@"addrs"];
    if (ips && [ips isKindOfClass:[NSArray class]] && [ips count] > 0) {
        return ips;
    }
    return @[];
}
@end
