//
//  CKQueueManager.h
//  CompassKit
//
//  Created by syosan on 2016/12/24.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CKQueueManager : NSObject
+ (NSOperationQueue *)getTaskQueue;
@end
