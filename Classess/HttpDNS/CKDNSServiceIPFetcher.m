//
//  CKDNSServiceIPFetcher.m
//  CompassKit
//
//  Created by darren.huang on 23/03/2018.
//  Copyright © 2018 Keeping. All rights reserved.
//

#import "CKDNSServiceIPFetcher.h"
#import <UIKit/UIKit.h>
#include <resolv.h>
#import <CommonCrypto/CommonDigest.h>
#import "CKLog.h"
typedef void(^CKServiceIPConnectionFinishCallback)(void);

static NSString *CKFallbackIPKey = @"CKFallbackIP";
static NSString *CKDNSTXTIPKey = @"CKDNSTXTIPKey";
static NSString *CKMainlandID = @"mainland";
static NSString *CKOverSeaID = @"oversea";
static dispatch_queue_t CKDNSTXTQueue () {
    static dispatch_queue_t workQueue;
    if (workQueue == nil) {
        workQueue = dispatch_queue_create("CKDNSTXTQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return workQueue;
}
//思路：step1.获取本地hardcode fallback IP,启动线程去获取新的fallback IP,如果获取成功，则更新本地fallback IP
//step2.启动DNS txt获取service IP,如果获取失败，则使用本地fallback IP作为service IP
//step2.1 fetchTXTRecords获取,返回结果类似：# httpdns ip1(十进制),httpdns ip2(十进制),(token+ip md5sum)
//                                         997165474,1778533773,3a9dd5dbcf82b01d12cca3348b2de276
//step2.2 校验MD5摘要  MD5(token,htpdns ip1,httpdns ip2) == step2.1.(token+ip md5sum) 确认token怎么设置?!文档说了，是自己申请
//step3.利用service IP 调用getHttpDNSResolving，获取域名对应的IP，实现DNS。contact杨博 HTTP请求头需要加入 AUTH-PROJECT、AUTH-TOKEN
//step3.1 请求格式为：https://httpdns ip/v2/?domain=login.netease.com

static BOOL isBeforeIOS6() {
    return [[[UIDevice currentDevice] systemVersion] floatValue] < 7.0;
}

static NSArray *fetchTXTRecords(NSString *domain) {
    // declare buffers / return array
    NSMutableArray *answers = [NSMutableArray new];
    u_char answer[1024];
    ns_msg msg;
    ns_rr rr;
    
    // initialize resolver
    res_init();
    
    // send query. res_query returns the length of the answer, or -1 if the query failed
    int rlen = res_query([domain cStringUsingEncoding:NSUTF8StringEncoding], ns_c_in, ns_t_txt, answer, sizeof(answer));
    
    if(rlen == -1) {
        return nil;
    }
    
    // parse the entire message
    if(ns_initparse(answer, rlen, &msg) < 0) {
        return nil;
    }
    
    // get the number of messages returned
    int rrmax = rrmax = ns_msg_count(msg, ns_s_an);
    
    // iterate over each message
    for(int i = 0; i < rrmax; i++) {
        // parse the answer section of the message
        if(ns_parserr(&msg, ns_s_an, i, &rr)) {
            return nil;
        }
        
        // obtain the record data
        const u_char *rd = ns_rr_rdata(rr);
        
        // the first byte is the length of the data
        size_t length = rd[0];
        
        // create and save a string from the C string
        NSString *record = [[NSString alloc] initWithBytes:(rd + 1) length:length encoding:NSUTF8StringEncoding];
        [answers addObject:record];
    }
    return answers;
}


#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

@interface CKDNSServiceIPFetcher ()
@property (nonatomic, strong) NSURLConnection *serviceIPConnection;
@property (nonatomic, strong) NSMutableData *updateServiceIPData;
@property (nonatomic, strong) NSMutableDictionary *DNSTXTDict;
@property (nonatomic, assign) int areaCode;
@property (nonatomic, copy)   CKServiceIPFetcheCompletionHandler serviceIPCompletionHandler;
@property (nonatomic, copy)   CKServiceIPConnectionFinishCallback serviceIPConnectionFinishCallback;
@property (nonatomic, copy)   NSDictionary *serviceIPDictionary;
@property (nonatomic, copy)   NSArray *domainArray;
@property (nonatomic, copy)   NSString *token;
@property (nonatomic, copy)   NSString *project;
@end


@implementation CKDNSServiceIPFetcher
+ (instancetype)shareFetcher {
    static dispatch_once_t onceToken;
    static CKDNSServiceIPFetcher *serviceIPFetcher = nil;
    dispatch_once(&onceToken, ^{
        serviceIPFetcher = [CKDNSServiceIPFetcher new];
    });
    return serviceIPFetcher;
}

- (void)fetchServiceIPByArea:(NSString *)area
                     domains:(NSArray *)domainArray
                       token:(NSString *)token
                     project:(NSString *)project
            completionHandler:(nonnull CKServiceIPFetcheCompletionHandler)handler{
    self.areaCode = area.intValue;
    self.domainArray = domainArray;
    self.token = token;
    self.project = project;
#warning testcode
    self.areaCode = 0;
    self.domainArray = @[@"hd.ntes53.netease.com"];
    self.project = @"foo";
    self.token = @"j5pLL6AY";
    self.serviceIPCompletionHandler = handler;
    self.DNSTXTDict = [NSMutableDictionary dictionary];
    //time line, local--> remote --> DNS TXT
    [self accessLocalServiceIP];
    
    __weak typeof(self) weakSelf = self;
    [self accessRemoteServiceIPWithCompletionHandler:^{
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf startDNSTXT];
    }];
}

- (void)startDNSTXT {
    for (NSString *domain in self.domainArray) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(CKDNSTXTQueue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            [strongSelf DNSTXTResult:domain];
        });
    }
    __weak typeof(self) weakSelf = self;
    dispatch_barrier_async(CKDNSTXTQueue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf.serviceIPCompletionHandler(strongSelf.DNSTXTDict);
    });
}

- (void)DNSTXTResult:(NSString *)domain {
    NSArray *DNSResultArray = fetchTXTRecords([NSString stringWithFormat:@"_%@.%@",self.project, domain]);
    if (!DNSResultArray.count) {
        return;
    }
    NSString *DNSTXTResult = DNSResultArray.lastObject;//997165474,1778533773,3a9dd5dbcf82b01d12cca3348b2de276
    NSArray *DNSInfoArray = [DNSTXTResult componentsSeparatedByString:@","];
    if (!DNSInfoArray.count) {
        return;
    }
    NSString *md5Sum = DNSInfoArray.lastObject;
    NSMutableArray *ipArray = [NSMutableArray array];
    for (int i = 0; i < DNSInfoArray.count - 1; i ++) {
        [ipArray addObject:(NSString *)[DNSInfoArray objectAtIndex:i]];
    }
    if (!ipArray.count) {
        return;
    }
    [self checkDNSTXTResultValidity:ipArray md5Sum:md5Sum domain:domain];
}

- (void)checkDNSTXTResultValidity:(NSArray *)ipArray md5Sum:(NSString *)md5Sum domain:(NSString *)domain{
    NSString *verifiedString = [self.token stringByAppendingString:[NSString stringWithFormat:@",%@",[ipArray componentsJoinedByString:@","]]];
    NSString *result = [self md5String:verifiedString];
    NSMutableArray *realIPV4Array = [NSMutableArray array];
    if ([result isEqualToString:md5Sum]) {
        CKLog(@"校验MD5 成功！");
        for (NSString *ipString in ipArray) {
            NSString *ipV4String = [self ipV4String:(uint32_t)(ipString.intValue)];
            NSLog(@"---%@",ipV4String);
            [realIPV4Array addObject:ipV4String];
        }
        if (realIPV4Array.count) {
            [self.DNSTXTDict setObject:realIPV4Array forKey:domain];
        }
    }else {
        CKLog(@"校验MD5 失败！")
    }
}

- (NSArray *)currentAreaFallbackIP:(NSDictionary *)serviceIPDictionary {
    NSString *areaString = nil;
    if (0 == self.areaCode) {
        /* 国内或者默认设置 */
        areaString = CKMainlandID;
    } else {
        /* 海外，台湾地区 */
        areaString = CKOverSeaID;
    }
    return (NSArray *)([serviceIPDictionary objectForKey:areaString]);
}

- (void)accessLocalServiceIP {
    NSDictionary *hardcodeIPDict = @{CKMainlandID:@[@"106.2.69.141"], CKOverSeaID:@[@"52.192.189.28"]};
    NSArray *hardcodeFallbackIPArray = [self currentAreaFallbackIP:hardcodeIPDict];
    if (hardcodeFallbackIPArray.count) {
        [self.DNSTXTDict setObject:hardcodeFallbackIPArray forKey:CKFallbackIPKey];
    }
}

- (void)accessRemoteServiceIPWithCompletionHandler:(CKServiceIPConnectionFinishCallback)serviceIPConnectionFinishCallback {
    self.serviceIPConnectionFinishCallback = serviceIPConnectionFinishCallback;
    NSURL *reqURL = [NSURL URLWithString:[self updateServiceIPURL]];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:reqURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:5.0];
    self.serviceIPConnection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self startImmediately:NO];
    [self.serviceIPConnection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [self.serviceIPConnection start];
}

#pragma mark - NSURLConnectionDataDelegate
-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSLog(@"__%s__",__PRETTY_FUNCTION__);
    if (connection == self.serviceIPConnection) {
        self.updateServiceIPData = [NSMutableData data];
    }
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    NSLog(@"__%s__",__PRETTY_FUNCTION__);
    if (connection == self.serviceIPConnection) {
        [self.updateServiceIPData appendData:data];
    }
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSLog(@"__%s__",__PRETTY_FUNCTION__);
    if (connection == self.serviceIPConnection) {
        (self.updateServiceIPData.length) ?
        [self connectionDidSuccess:connection] : [self connectionDidFailWithError:NULL connection:connection];
    }
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"__%s__",__PRETTY_FUNCTION__);
    [self connectionDidFailWithError:error connection:connection];
}


#pragma mark- 在请求将要被发送出去之前会调用,返回值是一个NSURLRequest,就是那个真正将要被发送的请求-darren.huang
- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(NSURLRequest *)request
            redirectResponse:(NSURLResponse *)response {
    NSLog(@"__%s__",__PRETTY_FUNCTION__);
    @autoreleasepool {
        if (response) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            if (httpResponse.statusCode == 302 || httpResponse.statusCode == 301 || httpResponse.statusCode == 307 || httpResponse.statusCode == 308) {
                NSMutableURLRequest *newRequrst = [request mutableCopy];
                if (request.URL && request.URL.host && ![[self class] isIPAddress:request.URL.host]) {
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
    NSLog(@"__%s__",__PRETTY_FUNCTION__);
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    NSLog(@"__%s__",__PRETTY_FUNCTION__);
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


#pragma mark- private
#pragma mark- remote service IP URL Builder
- (NSString *)updateServiceIPURL {
    NSString *configHost = nil;
    if (2 == self.areaCode) {
        /* 设置为台湾地区 */
        configHost = @"mbdl.update.easebar.com";
    } else {
        /* 海外，国内或者默认设置 */
        configHost = @"mbdl.update.netease.com";
    }
    return [NSString stringWithFormat:@"https://%@/httpdns.mbdl",configHost];
}

#pragma mark- connection handle
- (void)connectionDidSuccess:(NSURLConnection *)connection {
    if (connection == self.serviceIPConnection) {
        if (!self.updateServiceIPData.length) {
            [self connectionDidFailWithError:NULL connection:connection];
            return;
        }
        [self parseHttpDNSServiceConfiguration];
    }
}

- (void)connectionDidFailWithError:(NSError *)error connection:(NSURLConnection *)connection {
    if (connection == self.serviceIPConnection) {
        self.serviceIPConnectionFinishCallback();
        return;
    }
}

- (void)parseHttpDNSServiceConfiguration {
    NSData *serviceIPData = nil;
    if (isBeforeIOS6()) {
        NSString *fileString = [[NSString alloc] initWithData:self.updateServiceIPData encoding:NSUTF8StringEncoding];
        serviceIPData = [[NSData alloc] initWithBase64Encoding:fileString];
    } else {
        serviceIPData = [[NSData alloc] initWithBase64EncodedData:self.updateServiceIPData options:NSDataBase64DecodingIgnoreUnknownCharacters];
    }
    if (!serviceIPData) {
        NSLog(@"HttpDNS配置文件格式错误，请确认。");
        self.serviceIPConnectionFinishCallback();
        return;
    }
    
    //解析json数据，使用系统方法 JSONObjectWithData:  options: error:
    NSError *error = nil;
    NSDictionary *serviceIPDictionary = [NSJSONSerialization JSONObjectWithData:serviceIPData
                                                            options:NSJSONReadingMutableLeaves
                                                              error:&error];
    
    if(error || !serviceIPDictionary.count) {
        NSLog(@"HttpDNS Json Dictionary Err: %@.", [error localizedDescription]);
        self.serviceIPConnectionFinishCallback();
        return;
    }
    NSArray *updatedFallbackIPArray = [self currentAreaFallbackIP:serviceIPDictionary];
    if (updatedFallbackIPArray.count) {
        [self.DNSTXTDict setObject:updatedFallbackIPArray forKey:CKFallbackIPKey];
    }
    self.serviceIPConnectionFinishCallback();
}


#pragma mark- Utility
+ (BOOL)isIPAddress:(NSString *)ipaddr {
    @autoreleasepool {
        if (!ipaddr.length) {
            return NO;
        }
        // http://www.myexception.cn/program/564495.html
        NSRange iprange = [ipaddr rangeOfString:@"([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})|(((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:)))(%.+)?)" options:NSRegularExpressionSearch];
        return iprange.length != NSNotFound;
    }
}

- (NSString *)md5String:(NSString *)string {
    const char *cStr = [string UTF8String];
    unsigned char result[16];
    CC_MD5( cStr, (CC_LONG)(strlen(cStr)), result );
    return [[NSString stringWithFormat:
             @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
             result[0], result[1], result[2], result[3],
             result[4], result[5], result[6], result[7],
             result[8], result[9], result[10], result[11],
             result[12], result[13], result[14], result[15]
             ] lowercaseString];
}

- (NSString *)ipV4String:(uint32_t)decimalNum {
    uint8_t byte1 = (uint8_t)(decimalNum & 0xff);
    uint8_t byte2 = (uint8_t)((decimalNum>>8) & 0xff);
    uint8_t byte3 = (uint8_t)((decimalNum>>16) & 0xff);
    uint8_t byte4 = (uint8_t)((decimalNum>>24) & 0xff);
    return [NSString stringWithFormat:@"%d.%d.%d.%d",byte1, byte2, byte3, byte4];
}

@end

#pragma GCC diagnostic pop

