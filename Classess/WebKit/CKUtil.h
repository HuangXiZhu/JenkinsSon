//
//  CKUtil.h
//  CompassKit
//
//  Created by syosan on 16/9/2.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CKUtil : NSObject

#pragma mark - System Helper
/*
 * 获取系统相关的信息
 */
+ (NSString *)downloadSessionIdentifier;
+ (NSString *)downloadConfigTaskIdentifier;
+ (NSString *)downloadNormalTaskIdentifier;

#pragma mark - File Helper
/*
 * 获取文件相关的信息
 */
+ (NSString *)getDownloadFilePathExistWithName:(NSString*)defaultName;
+ (NSString *)getDownloadFilePathWithName:(NSString*)defaultName;
+ (NSString *)getDownloadTempPathWithName:(NSString*)defaultName;
+ (long long)getDownloadTempSizeWithName:(NSString*)defaultName;
+ (int)getDownloadTempCountWithName:(NSString*)defaultName;
+ (void)getDownloadTempFileRemoveWithName:(NSString*)defaultName;
+ (void)getDownloadTempFileAllRemove;
+ (NSString *)getDownloadTempFileCacheFloder;

/*
 * 读写日志文件相关
 */
+ (NSString *)getCKLogFileCacheFloder;
+ (NSString *)getCKLogFileFSQueueSeq;
+ (NSString *)getCKLogFileFromFSQueue:(NSString*)defaultName;
+ (BOOL)setCKLogFileToFSQueue:(NSString*)defaultName;
+ (void)getCKLogFileRemoveFromFSQueue:(NSString*)defaultName;

#pragma mark - Network Helper
/*
 * 获取网络相关的信息
 */
+ (NSString *)getDNSServer;
+ (NSString *)getIPAddress;
+ (NSString *)getHostWithoutScheme:(NSString *)url;
+ (NSString *)getCorrectString:(NSString *)content;
+ (NSString *)getUdid;
+ (NSString *)getMacAddress;
+ (NSString *)getNetworkConition;
+ (NSString *)getNetworkSignal;
+ (NSString *)getCarrier;
+ (NSString *)getTimezone;
+ (NSString *)getHostIp:(NSString *)host;
+ (NSString *)getUrlPath:(NSString *)url;
+ (BOOL)getContain:(NSString *)string withString:(NSString *)value;
+ (BOOL)isIPAddress:(NSString *)ipaddr;
+ (BOOL)isFileExits:(NSString *)defaultName;
+ (BOOL)isChinaMainlandArea;
@end
