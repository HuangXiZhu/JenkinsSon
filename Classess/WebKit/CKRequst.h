//
//  CKRequst.h
//  CompassKit
//
//  Created by syosan on 2016/12/22.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CKRequst : NSMutableURLRequest
@property (nullable, strong, nonatomic) NSString *host;
@property (nullable, strong, nonatomic) NSString *hostIp;
- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(nonnull NSString *)field;
- (void)setValue:(nullable id)value forKey:(nonnull NSString *)key;
@end
