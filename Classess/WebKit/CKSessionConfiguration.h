//
//  CKSessionConfiguration.h
//  CompassKit
//
//  Created by syosan on 2016/12/16.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CKSessionConfiguration : NSObject
+ (NSURLSessionConfiguration *)get;
+ (NSURLSessionConfiguration *)getWithIdentifier:(NSString *)identifier;
@end
