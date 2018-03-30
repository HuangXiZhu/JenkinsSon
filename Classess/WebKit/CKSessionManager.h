//
//  CKSessionManager.h
//  CompassKit
//
//  Created by syosan on 2016/12/16.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CKSessionManager : NSObject

+ (nonnull NSURLSession *)sessionViaHost:(NSString * _Nonnull)host;

@end
