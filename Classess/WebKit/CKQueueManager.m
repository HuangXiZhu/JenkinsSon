//
//  CKQueueManager.m
//  CompassKit
//
//  Created by syosan on 2016/12/24.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#import "CKQueueManager.h"
#import "CKLog.h"

#define DOWN_QUEUE_MANAGER [CKQueueManager getInst]

@implementation CKQueueManager

+ (NSOperationQueue *)getInst
{
    static NSOperationQueue *CKQueueManager = nil;
    static dispatch_once_t CKQueueManagerToken;
    dispatch_once(&CKQueueManagerToken, ^{
        CKQueueManager = [[NSOperationQueue alloc] init];
        
    });
    return CKQueueManager;
}

+ (NSOperationQueue *)getTaskQueue
{
    static NSOperationQueue *downloadTaskQueue = nil;
    static dispatch_once_t downloadTaskQueueToken;
    dispatch_once(&downloadTaskQueueToken, ^{
        downloadTaskQueue = [[NSOperationQueue alloc] init];
//        [downloadTaskQueue addObserver:DOWN_QUEUE_MANAGER forKeyPath:@"operations" options:NSKeyValueObservingOptionNew context:NULL];

    });
    return downloadTaskQueue;
}



- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    CKLog(@"%@%@", object, change);
    NSOperationQueue *queue = (NSOperationQueue *)object;
    
    CKLog(@"The queue in KVO: %@", queue);
    CKLog(@"Max op Count in KVO: %li", (long)queue.maxConcurrentOperationCount);
        
}

@end
