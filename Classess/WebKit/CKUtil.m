//
//  CKUtil.m
//  CompassKit
//
//  Created by syosan on 16/9/2.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#import "CKUtil.h"
#import "CKLog.h"

#import <UIKit/UIKit.h>
#import <CFNetwork/CFHost.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#import <netdb.h>
#import <arpa/inet.h>
#import <resolv.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
#import <sys/utsname.h>

/* getMacAddress */
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if_dl.h>

#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <SystemConfiguration/SystemConfiguration.h>
/* idfa  */
#import <AdSupport/ASIdentifierManager.h>
/* idfa  */

extern BOOL CKConfigurationAllowX86_64;

@implementation CKUtil

+ (NSString *)downloadTaskIdentifier:(NSString *)prefix
{
//    char data[32];
//    for (int x=0;x<32;data[x++] = (char)('A' + (arc4random_uniform(26))));
//    return [[NSString alloc] initWithBytes:data length:32 encoding:NSUTF8StringEncoding];
    
    NSDateFormatter *dfm = [[NSDateFormatter alloc] init];
    [dfm setDateFormat:@"yyyyMMddHHmmssSSS"];
    NSString *cdString = [dfm stringFromDate:[NSDate date]];
    
    NSString *identifier = @"IOS_";
    identifier = [identifier stringByAppendingString:prefix];
    NSString *seq = @"";//[[NSNumber numberWithInt:arc4random_uniform(INT_MAX)] stringValue];
    for(int i = 0; i < 9; i++)
    {
        seq = [seq stringByAppendingFormat:@"%i",arc4random_uniform(10)];//[0,10)
    }
    identifier = [identifier stringByAppendingString:cdString];
    return [identifier stringByAppendingString:seq];
}

+ (NSString *)downloadSessionIdentifier
{
    static NSString *_downloadSessionIdentifier = nil;
    static dispatch_once_t downloadSessionIdentifierToken;
    dispatch_once(&downloadSessionIdentifierToken, ^{
        _downloadSessionIdentifier = [CKUtil downloadTaskIdentifier:@""];
    });
    return _downloadSessionIdentifier;
}

+ (NSString *)downloadNormalTaskIdentifier
{
    return [CKUtil downloadTaskIdentifier:@"UDT_"];
}

+ (NSString *)downloadConfigTaskIdentifier
{
    return [CKUtil downloadTaskIdentifier:@"CFG_"];
}

+ (BOOL)getContain:(NSString *)string withString:(NSString *)value
{
    if (!string || [@"" isEqualToString:string] || !value || [@"" isEqualToString:value]) {
        return NO;
    }
    if ([string rangeOfString:value].location != NSNotFound) {
        return YES;
    }
    return NO;
}

+ (BOOL)isIPAddress:(NSString *)ipaddr
{
    if (!ipaddr) {
        return NO;
    }
    // http://www.myexception.cn/program/564495.html
    NSRange iprange = [ipaddr rangeOfString:@"([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})|(((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:)))(%.+)?)" options:NSRegularExpressionSearch];
    if (iprange.location == NSNotFound) {
        return NO;
    } else {
        return YES;
    }
}

+ (BOOL)isChinaMainlandArea
{
    NSString *timezone = [CKUtil getTimezone];
    CKLog(@"Zone: %@",timezone);
    if ([@"Asia/Shanghai" isEqualToString:timezone]) {
        return YES;
    }
    return NO;
}

+ (BOOL)isFileExits:(NSString *)defaultName
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *URLs = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documentsDirectory = URLs[0];
    NSURL *destinationURL = [documentsDirectory URLByAppendingPathComponent:defaultName];
    NSString *destinationPath = [destinationURL path];
    NSString *deletingLastPath = [destinationPath stringByDeletingLastPathComponent];
    BOOL existed = [fileManager fileExistsAtPath:deletingLastPath];
    return existed;
}

+ (NSString *)getDownloadFilePathExistWithName:(NSString*)defaultName
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *URLs = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documentsDirectory = URLs[0];
    NSURL *destinationURL = [documentsDirectory URLByAppendingPathComponent:defaultName];
    NSString *destinationPath = [destinationURL path];
    return destinationPath;
}

+ (NSString *)getDownloadFilePathWithName:(NSString*)defaultName
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *URLs = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documentsDirectory = URLs[0];
    NSURL *destinationURL = [documentsDirectory URLByAppendingPathComponent:defaultName];
    NSString *destinationPath = [destinationURL path];
    NSString *deletingLastPath = [destinationPath stringByDeletingLastPathComponent];
    BOOL existed = [fileManager fileExistsAtPath:deletingLastPath];
    if ( !existed ) {
        [fileManager createDirectoryAtPath:deletingLastPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    existed = [fileManager fileExistsAtPath:destinationPath];
    if ( !existed ) {
        [fileManager createFileAtPath:destinationPath contents:nil attributes:nil];
    }
    return destinationPath;
}

+ (NSString *)getDownloadTempFileCacheFloder
{
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *tmpPath = [tmpDir stringByAppendingPathComponent:@"com_mask_downloader_cahce_tmp"];
    NSError *error = nil;
    BOOL isDirectory = YES;
    BOOL ret = [[NSFileManager defaultManager] fileExistsAtPath:tmpPath isDirectory:&isDirectory];
    if (ret && !error) {
        return tmpPath;
    }
    error = nil;
    ret = [[NSFileManager defaultManager] createDirectoryAtPath:tmpPath withIntermediateDirectories:YES attributes:nil error:&error];
    if (ret && !error) {
        CKLog(@"DownFileCacheFloder: %@",tmpPath);
        return tmpPath;
    }
    return tmpDir;
}

+ (NSString *)getDownloadTempPathWithName:(NSString*)defaultName
{
    NSString *tmpPath = [[CKUtil getDownloadTempFileCacheFloder] stringByAppendingPathComponent:defaultName];
    BOOL ret = [[NSFileManager defaultManager] fileExistsAtPath:tmpPath];
    if (!ret) {
        [[NSFileManager defaultManager] createFileAtPath:tmpPath contents:nil attributes:nil];
    }
    return tmpPath;
}

+ (long long)getDownloadTempSizeWithName:(NSString*)defaultName
{
    NSString *downFilePath = [CKUtil getDownloadTempPathWithName:defaultName];
    long long fileSize = 0;
    NSError *error = nil;
    NSDictionary *fileDict = [[NSFileManager defaultManager] attributesOfItemAtPath:downFilePath error:&error];
    if (!error && fileDict) {
        fileSize = [fileDict fileSize];
    }
    return fileSize;
}

+ (int)getDownloadTempCountWithName:(NSString*)defaultName
{
    int tmpCount = 0;
    if (!defaultName || [@"" isEqualToString:defaultName]) {
        return tmpCount;
    }
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *tmp = [tmpDir stringByAppendingPathComponent:@"com_mask_downloader_cahce_tmp"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *tempFileList = [[NSArray alloc] initWithArray:[fileManager contentsOfDirectoryAtPath:tmp error:nil]];
    NSString *searchName = [[defaultName lastPathComponent] stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    searchName = [searchName stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    searchName = [searchName stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    for (NSUInteger row = 0; row < [tempFileList count]; row++) {
        NSString *tempFileName = [tempFileList objectAtIndex:row];
        if ([CKUtil getContain:tempFileName withString:@"BYTE_"] && [CKUtil getContain:tempFileName withString:searchName]) {
            tmpCount++;
        }
    }
    CKLog(@"Temp file %@ resouces searching from TMP count: %d.",defaultName,tmpCount);
    return tmpCount;
}

+ (void)getDownloadTempFileRemoveWithName:(NSString*)defaultName
{
    if (!defaultName || [@"" isEqualToString:defaultName]) {
        return;
    }
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *tmp = [tmpDir stringByAppendingPathComponent:@"com_mask_downloader_cahce_tmp"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *tempFileList = [[NSArray alloc] initWithArray:[fileManager contentsOfDirectoryAtPath:tmp error:nil]];
    CKLog(@"Download temp resouces Total count %ld.",(long)[tempFileList count]);
    NSString *searchName = [[defaultName lastPathComponent] stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    searchName = [searchName stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    searchName = [searchName stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    for (NSUInteger row = 0; row < [tempFileList count]; row++) {
        NSString *tempFileName = [tempFileList objectAtIndex:row];
        if ([CKUtil getContain:tempFileName withString:searchName]) {
            CKLog(@"Temp file %@ resouces removing from TMP.",tempFileName);
            NSString *fullTempPath = [tmp stringByAppendingPathComponent:tempFileName];
            if ([[NSFileManager defaultManager] fileExistsAtPath:fullTempPath]) {
                [[NSFileManager defaultManager] removeItemAtPath:fullTempPath error:nil];
            }
        }
    }
}

+ (void)getDownloadTempFileAllRemove
{
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *tmpPath = [tmpDir stringByAppendingPathComponent:@"com_mask_downloader_cahce_tmp"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tmpPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
    }
}

/*
 * 读写日志文件相关
 */
+ (NSString *)getCKLogFileCacheFloder
{
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *tmp = [tmpDir stringByAppendingPathComponent:@"com_mask_downloader_cahce_log"];
    NSError *error = nil;
    BOOL isDirectory = YES;
    BOOL ret = [[NSFileManager defaultManager] fileExistsAtPath:tmp isDirectory:&isDirectory];
    if (ret && !error) {
        return tmp;
    }
    error = nil;
    ret = [[NSFileManager defaultManager] createDirectoryAtPath:tmp withIntermediateDirectories:YES attributes:nil error:&error];
    if (ret && !error) {
        CKLog(@"LogFileCacheFloder: %@",tmp);
        return tmp;
    }
    return nil;
}

+ (NSString *)getCKLogFileFSQueueSeq
{
    NSString *tmp = [CKUtil getCKLogFileCacheFloder];
    if (!tmp) { return nil; }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *tempFileList = [[NSArray alloc] initWithArray:[fileManager contentsOfDirectoryAtPath:tmp error:nil]];
    return [tempFileList firstObject];
}

+ (NSString *)getCKLogFileFromFSQueue:(NSString*)defaultName
{
    if(!defaultName) { return nil; }
    
    NSString *tmp = [CKUtil getCKLogFileCacheFloder];
    if (!tmp) { return nil; }
    NSString *tmpPath = [tmp stringByAppendingPathComponent:defaultName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tmpPath]) {
        
        NSError *error = nil;
        NSData *data = [NSData dataWithContentsOfFile:tmpPath];
        
        if(!data) { return nil; }
        return [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    return nil;
}

+ (BOOL)setCKLogFileToFSQueue:(NSString*)defaultName
{
    if(!defaultName) { return YES; }
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:defaultName];
    if(!data) { return NO; }
    
    NSString *tmp = [CKUtil getCKLogFileCacheFloder];
    if (!tmp) { return NO; }
    
    NSString *tmpPath = [tmp stringByAppendingPathComponent:[CKUtil downloadTaskIdentifier:@"DL"]];
    if(![data writeToFile:tmpPath atomically:YES])
    {
        return NO;
    }
    return YES;
}

+ (void)getCKLogFileRemoveFromFSQueue:(NSString*)defaultName
{
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *tmp = [tmpDir stringByAppendingPathComponent:@"com_mask_downloader_cahce_log"];
    NSString *tmpPath = [tmp stringByAppendingPathComponent:defaultName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tmpPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
    }
}

/*
 * 获取网络相关的信息
 */
+ (NSString *)getDNSServer
{
    // dont forget to link libresolv.lib
    NSMutableString *addresses = [NSMutableString string];
    
    res_state res = malloc(sizeof(struct __res_state));
    
    int result = res_ninit(res);
    
    if ( result == 0 )
    {
        union res_9_sockaddr_union *addr_union = malloc(res->nscount * sizeof(union res_9_sockaddr_union));
        res_getservers(res, addr_union, res->nscount);
        
        for ( int i = 0; i < res->nscount; i++ )
        {
            if (addr_union[i].sin.sin_family == AF_INET) {
                char ip[INET_ADDRSTRLEN];
                inet_ntop(AF_INET, &(addr_union[i].sin.sin_addr), ip, INET_ADDRSTRLEN);
                NSString *dnsIP = [NSString stringWithUTF8String:ip];
                [addresses appendFormat:@"%@", dnsIP];
                break;
            } else if (addr_union[i].sin6.sin6_family == AF_INET6) {
                char ip[INET6_ADDRSTRLEN];
                inet_ntop(AF_INET6, &(addr_union[i].sin6.sin6_addr), ip, INET6_ADDRSTRLEN);
                NSString *dnsIP = [NSString stringWithUTF8String:ip];
                [addresses appendFormat:@"%@", dnsIP];
                break;
            } else {
                CKLog(@"Undefined family.");
            }
        }
        
        if (addr_union) {
            free(addr_union);
        }
        
    } else {
        [addresses appendString:@" res_init result != 0"];
    }
    
    res_nclose(res);
    
    return addresses;
}

+ (NSString *)getIPAddress
{
    // preferIPv4 ? YES
    BOOL preferIPv4 = YES;
    NSArray *searchArray = preferIPv4 ?
    @[ /*IOS_VPN @"/" @"ipv4", IOS_VPN @"/" @"ipv6",*/ @"en0" @"/" @"ipv4", @"en0" @"/" @"ipv6", @"pdp_ip0" @"/" @"ipv4", @"pdp_ip0" @"/" @"ipv6" ] :
    @[ /*IOS_VPN @"/" @"ipv6", IOS_VPN @"/" @"ipv4",*/ @"en0" @"/" @"ipv6", @"en0" @"/" @"ipv4", @"pdp_ip0" @"/" @"ipv6", @"pdp_ip0" @"/" @"ipv4" ] ;
    
    NSDictionary *addresses = [CKUtil getIPAddresses];
    CKLog(@"addresses: %@", addresses);
    
    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
     {
         address = addresses[key];
         if(address) *stop = YES;
     } ];
    
    return address ? address : @"0.0.0.0";
}

+ (NSDictionary *)getIPAddresses {
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = @"ipv4";
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = @"ipv6";
                    }
                }
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}

+ (NSString *)getHostWithoutScheme:(NSString *)url {
    NSString *host = [url stringByReplacingOccurrencesOfString:@"http://" withString:@""];
    host = [host stringByReplacingOccurrencesOfString:@"https://" withString:@""];
    return host;
}

+ (NSString *)getCorrectString:(NSString *)content {
    NSCharacterSet *controlChars = [NSCharacterSet controlCharacterSet];
    //获取那些特殊字符
    NSRange range = [content rangeOfCharacterFromSet:controlChars];
    //寻找字符串中有没有这些特殊字符
    if (range.location != NSNotFound) {
        NSMutableString *mutable = [NSMutableString stringWithString:content];
        while (range.location != NSNotFound) {
            [mutable deleteCharactersInRange:range];
            //去掉这些特殊字符
            range = [mutable rangeOfCharacterFromSet:controlChars];
        }
        return mutable;
    }
    return content;
}

+ (NSString *)getUdid
{
    //iOS version is equal or larger than 10.0
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 10.0) {
        BOOL advertisingTrackingEnabled = [[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled];
        if (advertisingTrackingEnabled) {
            NSString *idfaString = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
            return idfaString;
        }
        else {
            //idfv may be nil in some cases
            NSString *idfvString = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
            if (!idfvString) {
                idfvString = @"";
            }
            return idfvString;
        }
    }
    
    //iOS version is equal or larger than 6.0 smaller than 10.0
    else if ([[UIDevice currentDevice].systemVersion floatValue] >= 6.0) {
        NSString *idfaString = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
        return idfaString;
    }
    
    else {
        return [CKUtil getMacAddress];
    }
}

+ (NSString *)getMacAddress
{
    NSString            *errorFlag = @"getMacFailed";
    
    int                 mgmtInfoBase[6];
    char                *msgBuffer = NULL;
    size_t              length;
    
    // Setup the management Information Base (mib)
    mgmtInfoBase[0] = CTL_NET;        // Request network subsystem
    mgmtInfoBase[1] = AF_ROUTE;       // Routing table info
    mgmtInfoBase[2] = 0;
    mgmtInfoBase[3] = AF_LINK;        // Request link layer information
    mgmtInfoBase[4] = NET_RT_IFLIST;  // Request all configured interfaces
    
    // With all configured interfaces requested, get handle index
    if ((mgmtInfoBase[5] = if_nametoindex("en0")) == 0)
        errorFlag = @"if_nametoindex failure";
    // Get the size of the data available (store in len)
    else if (sysctl(mgmtInfoBase, 6, NULL, &length, NULL, 0) < 0)
        errorFlag = @"sysctl mgmtInfoBase failure";
    // Alloc memory based on above call
    else if ((msgBuffer = malloc(length)) == NULL)
        errorFlag = @"buffer allocation failure";
    // Get system information, store in buffer
    else if (sysctl(mgmtInfoBase, 6, msgBuffer, &length, NULL, 0) < 0)
    {
        free(msgBuffer);
        errorFlag = @"sysctl msgBuffer failure";
    }
    else
    {
        // Map msgbuffer to interface message structure
        struct if_msghdr *interfaceMsgStruct = (struct if_msghdr *) msgBuffer;
        
        // Map to link-level socket structure
        struct sockaddr_dl *socketStruct = (struct sockaddr_dl *) (interfaceMsgStruct + 1);
        
        // Copy link layer address data in socket structure to an array
        unsigned char macAddress[6];
        memcpy(&macAddress, socketStruct->sdl_data + socketStruct->sdl_nlen, 6);
        
        // Read from char array into a string object, into traditional Mac address format
        NSString *macAddressString = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
                                      macAddress[0], macAddress[1], macAddress[2], macAddress[3], macAddress[4], macAddress[5]];
        CKLog(@"Mac Address: %@", macAddressString);
        
        // Release the buffer memory
        free(msgBuffer);
        
        return macAddressString;
    }
    
    // Error...
    CKLog(@"Error: %@", errorFlag);
    
    return errorFlag;
}

+ (NSString *)getNetworkConition
{
    NSString *strNetworkType = @"unknown";
    
    //创建零地址，0.0.0.0的地址表示查询本机的网络连接状态
    struct sockaddr_storage zeroAddress;
    
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.ss_len = sizeof(zeroAddress);
    zeroAddress.ss_family = AF_INET6;
    
    // Recover reachability flags
    SCNetworkReachabilityRef defaultRouteDownloadReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
    SCNetworkReachabilityFlags flags;
    
    //获得连接的标志
    BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteDownloadReachability, &flags);
    CFRelease(defaultRouteDownloadReachability);
    
    //如果不能获取连接标志，则不能连接网络，直接返回
    if (!didRetrieveFlags)
    {
        return strNetworkType;
    }
    
    
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
    {
        // if target host is reachable and no connection is required
        // then we'll assume (for now) that your on Wi-Fi
        strNetworkType = @"wifi";
    }
    
    if (
        ((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
        (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0
        )
    {
        // ... and the connection is on-demand (or on-traffic) if the
        // calling application is using the CFSocketStream or higher APIs
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
        {
            // ... and no [user] intervention is needed
            strNetworkType = @"wifi";
        }
    }
    
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
    {
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0)
        {
            CTTelephonyNetworkInfo * info = [[CTTelephonyNetworkInfo alloc] init];
            NSString *currentRadioAccessTechnology = info.currentRadioAccessTechnology;
            
            if (currentRadioAccessTechnology)
            {
                if ([currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyLTE])
                {
                    strNetworkType =  @"4G";
                }
                else if ([currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyEdge] || [currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyGPRS] || [CTRadioAccessTechnologyCDMA1x isEqualToString:currentRadioAccessTechnology])
                {
                    strNetworkType =  @"2G";
                }
                else
                {
                    strNetworkType =  @"3G";
                }
            }
        }
        else
        {
            if((flags & kSCNetworkReachabilityFlagsReachable) == kSCNetworkReachabilityFlagsReachable)
            {
                if ((flags & kSCNetworkReachabilityFlagsTransientConnection) == kSCNetworkReachabilityFlagsTransientConnection)
                {
                    if((flags & kSCNetworkReachabilityFlagsConnectionRequired) == kSCNetworkReachabilityFlagsConnectionRequired)
                    {
                        strNetworkType = @"2G";
                    }
                    else
                    {
                        strNetworkType = @"3G";
                    }
                }
            }
        }
    }
    
    return strNetworkType;
}

+ (NSString *)getNetworkType
{
    /*
     * 通过状态栏获取网络类型，跟getNetworkConition功能一致
     */
//    NSArray *infoArray = [[[[UIApplication sharedApplication] valueForKeyPath:@"statusBar"] valueForKeyPath:@"foregroundView"] subviews];
    
    UIApplication *application = [UIApplication sharedApplication];
    NSArray *subviews = [[[application valueForKey:@"statusBar"] valueForKey:@"foregroundView"] subviews];
    NSString *dataNetworkItemView = nil;
    for (id subview in subviews) {
        if([subview isKindOfClass:[NSClassFromString(@"UIStatusBarDataNetworkItemView") class]]) {
            dataNetworkItemView = subview;
            break;
        }
    }
    NSInteger type = [[dataNetworkItemView valueForKeyPath:@"dataNetworkType"] integerValue];
    
    //0 - 无网络 ; 1 - 2G ; 2 - 3G ; 3 - 4G ; 5 - WIFI
    if (1 == type) {
        return @"2G";
    } else if (2 == type) {
        return @"3G";
    } else if (3 == type) {
        return @"4G";
    } else if (4 == type) {
        return @"wifi";
    } else {
        return @"unknown";
    }
}

+ (NSString *)getNetworkSignal
{
    @autoreleasepool {
        
        BOOL ip11_x = NO;
        struct utsname systemInfo;
        uname(&systemInfo);
        NSString *deviceString = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
        if (deviceString) {
            NSRange range1 = [deviceString rangeOfString:@"iPhone10," options:NSRegularExpressionSearch];
            if (range1.location != NSNotFound) {
                ip11_x = YES;
            }
            if (!ip11_x && CKConfigurationAllowX86_64) {
                NSRange range2 = [deviceString rangeOfString:@"x86_64" options:NSRegularExpressionSearch];
                if (range2.location != NSNotFound) {
                    ip11_x = YES;
                }
            }
        }
        if (!ip11_x && [[[UIDevice currentDevice] systemVersion] floatValue] < 11) {
            UIApplication *application = [UIApplication sharedApplication];
            NSArray *subviews = [[[application valueForKey:@"statusBar"] valueForKey:@"foregroundView"] subviews];
            NSString *dataNetworkItemView = nil;
            for (id subview in subviews) {
                if([subview isKindOfClass:[NSClassFromString(@"UIStatusBarDataNetworkItemView") class]]) {
                    dataNetworkItemView = subview;
                    break;
                }
            }
            NSString *signalStrength = [[dataNetworkItemView valueForKey:@"_wifiStrengthBars"] stringValue];
            return signalStrength;
        } else if (ip11_x) {
            UIApplication *application = [UIApplication sharedApplication];
            id statusBarModern = [application valueForKey:@"statusBar"];
            if (statusBarModern && [statusBarModern valueForKey:@"statusBar"]) {
                id statusBar = [statusBarModern valueForKey:@"statusBar"];
                NSDictionary *regions = [statusBar valueForKey:@"regions"];
                if (regions && [regions isKindOfClass:[NSDictionary class]] && [regions count] > 0) {
                    id statusBarRegion = [regions objectForKey:@"trailing"];
                    if (statusBarRegion) {
                        id statusData = [statusBarRegion valueForKeyPath:@"statusBar.currentData"];
                        id wifiEntry = [statusData valueForKey:@"wifiEntry"];
                        NSString *wifi = [NSString stringWithFormat:@"%@",wifiEntry];
                        NSArray *wifis = [wifi componentsSeparatedByString:@","];
                        if (wifis && [wifis isKindOfClass:[NSArray class]] && [wifis count] > 0) {
                            for (NSString *row in wifis) {
                                @autoreleasepool {
                                    if (row && [row length] > 0) {
                                        NSArray *rows = [row componentsSeparatedByString:@"="];
                                        if (rows && [rows isKindOfClass:[NSArray class]] && [rows count] == 2) {
                                            NSString *text = [NSString stringWithFormat:@"%@",[rows objectAtIndex:0]];
                                            text = [text stringByReplacingOccurrencesOfString:@" " withString:@""];
                                            if ([@"displayValue" isEqualToString:text]) {
                                                return [rows objectAtIndex:1];
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return @"3";
    }
}

+ (NSString *)getCarrier
{
    @autoreleasepool {
        
        BOOL ip11_x = NO;
        struct utsname systemInfo;
        uname(&systemInfo);
        NSString *deviceString = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
        if (deviceString) {
            NSRange range1 = [deviceString rangeOfString:@"iPhone10," options:NSRegularExpressionSearch];
            if (range1.location != NSNotFound) {
                ip11_x = YES;
            }
            if (!ip11_x && CKConfigurationAllowX86_64) {
                NSRange range2 = [deviceString rangeOfString:@"x86_64" options:NSRegularExpressionSearch];
                if (range2.location != NSNotFound) {
                    ip11_x = YES;
                }
            }
        }
        if (!ip11_x && [[[UIDevice currentDevice] systemVersion] floatValue] < 11) {
            UIApplication *application = [UIApplication sharedApplication];
            NSArray *subviews = [[[application valueForKey:@"statusBar"] valueForKey:@"foregroundView"] subviews];
            NSString *dataServiceItemView = nil;
            for (id subview in subviews) {
                if([subview isKindOfClass:[NSClassFromString(@"UIStatusBarServiceItemView") class]]) {
                    dataServiceItemView = subview;
                    break;
                }
            }
            NSString *type = [[dataServiceItemView valueForKey:@"serviceString"] stringValue];
            return type;
        } else if (ip11_x) {
            UIApplication *application = [UIApplication sharedApplication];
            id statusBarModern = [application valueForKey:@"statusBar"];
            if (statusBarModern && [statusBarModern valueForKey:@"statusBar"]) {
                id statusBar = [statusBarModern valueForKey:@"statusBar"];
                NSDictionary *regions = [statusBar valueForKey:@"regions"];
                if (regions && [regions isKindOfClass:[NSDictionary class]] && [regions count] > 0) {
                    id statusBarRegion = [regions objectForKey:@"trailing"];
                    if (statusBarRegion) {
                        id statusData = [statusBarRegion valueForKeyPath:@"statusBar.currentData"];
                        id cellularEntry = [statusData valueForKey:@"cellularEntry"];
                        NSString *cellular = [NSString stringWithFormat:@"%@",cellularEntry];
                        NSArray *cellulars = [cellular componentsSeparatedByString:@","];
                        if (cellulars && [cellulars isKindOfClass:[NSArray class]] && [cellulars count] > 0) {
                            for (NSString *row in cellulars) {
                                @autoreleasepool {
                                    if (row && [row length] > 0) {
                                        NSArray *rows = [row componentsSeparatedByString:@"="];
                                        if (rows && [rows isKindOfClass:[NSArray class]] && [rows count] == 2) {
                                            NSString *text = [NSString stringWithFormat:@"%@",[rows objectAtIndex:0]];
                                            text = [text stringByReplacingOccurrencesOfString:@" " withString:@""];
                                            if ([@"string" isEqualToString:text]) {
                                                return [rows objectAtIndex:1];
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return @"unkown";
    }
}

+ (NSString *)getTimezone
{
    NSTimeZone *zone = [NSTimeZone systemTimeZone];
    return [zone name];
}

+ (NSString *)getHostIp:(NSString *)host
{
    Boolean result = '\0', bResolved;
    CFHostRef hostRef;
    CFArrayRef addresses = NULL;
    
    CFStringRef hostNameRef = CFStringCreateWithCString(kCFAllocatorDefault, [host UTF8String], kCFStringEncodingASCII);
    
    hostRef = CFHostCreateWithName(kCFAllocatorDefault, hostNameRef);
    if (hostRef) {
        result = CFHostStartInfoResolution(hostRef, kCFHostAddresses, NULL);
        if (result == TRUE) {
            addresses = CFHostGetAddressing(hostRef, &result);
        }
    }
    bResolved = result == TRUE ? true : false;
    
    NSString *ipAddress = @"NULL";
    
    if(bResolved)
    {
        struct sockaddr_in* addr;
        for (int i = 0; i < CFArrayGetCount(addresses); i++)
        {
            CFDataRef saData = (CFDataRef)CFArrayGetValueAtIndex(addresses, i);
            addr = (struct sockaddr_in*)CFDataGetBytePtr(saData);
            
            if (addr != NULL)
            {
                //获取IP地址
                char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
                if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                    NSString *type;
                    if(addr->sin_family == AF_INET) {
                        if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                            type = @"ipv4";
                        }
                    } else {
                        const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)addr;
                        if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                            type = @"ipv6";
                        }
                    }
                    if(type) {
                        ipAddress = [NSString stringWithUTF8String:addrBuf];
                    }
                }
            }
        }
    }
    CFRelease(hostNameRef);
    CFRelease(hostRef);
    
    return ipAddress;
}

+ (NSString *)getUrlPath:(NSString *)url
{
    if (!url || [@"" isEqualToString:url]) { return @""; }
    NSString *stringURL = nil;
    if ([[[UIDevice currentDevice] systemVersion] floatValue]>=9.0) {
        stringURL = [url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    } else {
        stringURL = [url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    if (!stringURL || [@"" isEqualToString:stringURL]) { return @""; }
    NSURL *URL = [NSURL URLWithString:stringURL];
    return URL.path ? URL.path : @"";
}

@end
