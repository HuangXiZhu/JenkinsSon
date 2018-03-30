//
//  CKSessionManager.m
//  CompassKit
//
//  Created by syosan on 2016/12/16.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#import "CKSessionManager.h"
#import "CKSessionResponse.h"
#import "CKSessionConfiguration.h"
#import "CKQueueManager.h"
#import "CKLog.h"

extern BOOL       CKConfigurationWifiOnly;

static CKSessionManager *currentSessionManager = nil;

@interface CKSessionManager ()
@property (nullable, strong, nonatomic) NSURLSession *session;
@property (nullable, strong, nonatomic) NSMutableDictionary *hostSessions;
@end

#define NGWK_SESSION_MANAGER [CKSessionManager getInst]
@implementation CKSessionManager

- (void)dealloc
{
    [_hostSessions removeAllObjects];
    [_session invalidateAndCancel];
    _session = nil;
    _hostSessions = nil;
    currentSessionManager = nil;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _hostSessions = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSURLSession *)session
{
    if (_session) { return _session; }
    /* 单例Session */
    [CKSessionConfiguration get].allowsCellularAccess = !CKConfigurationWifiOnly;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[CKSessionConfiguration get] delegate:[CKSessionResponse get] delegateQueue:[CKQueueManager getTaskQueue]];
    _session = session;
    return _session;
}

+ (CKSessionManager *)getInst
{
    static dispatch_once_t sessionManagerToken;
    dispatch_once(&sessionManagerToken, ^{
        currentSessionManager = [[CKSessionManager alloc] init];
    });
    return currentSessionManager;
}

+ (nonnull NSURLSession *)sessionViaHost:(NSString *)host
{
    if (host && ![NGWK_SESSION_MANAGER.hostSessions objectForKey:host]) {
        [NGWK_SESSION_MANAGER.hostSessions setObject:@"SESSION" forKey:host];
    }
    return NGWK_SESSION_MANAGER.session;
}

@end
