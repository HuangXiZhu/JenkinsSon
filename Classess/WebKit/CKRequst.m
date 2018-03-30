//
//  CKRequst.m
//  CompassKit
//
//  Created by syosan on 2016/12/22.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#import "CKRequst.h"
#import "CKLog.h"

@implementation CKRequst

- (instancetype)init
{
    self = [super init];
    if (self) {
        _hostIp = @"";
        _host = @"";
    }
    return self;
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    [super setValue:value forHTTPHeaderField:field];
}

- (void)setValue:(id)value forKey:(NSString *)key {
    [super setValue:value forKey:key];
}

@end
