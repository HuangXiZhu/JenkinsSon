//
//  CKRequstManager.h
//  CompassKit
//
//  Created by syosan on 2016/12/22.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CKRequst.h"

@interface CKRequstManager : NSObject
+ (NSString *)getHostIp:(NSString *)host;
+ (CKRequst*)getViaURL:(NSString *)url host:(NSString *)host encoding:(BOOL)disable;
@end
