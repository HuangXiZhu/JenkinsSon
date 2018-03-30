//
//  CKSession.h
//  CompassKit
//
//  Created by syosan on 2016/12/18.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CKRequst.h"

@interface CKSessionTask : NSObject
@property (assign, nonatomic) BOOL sessionIgnoreCerTrust;
@property (assign, nonatomic) int  sessionPerformingArea;
@property (nonnull, nonatomic, strong, readonly) NSString *sessionTaskPtr;
- (void)dataTaskRequst:(CKRequst * _Nonnull)request didReceiveData:(void (^ _Nullable)(NSData * _Nullable data))recvData hiJackHandler:(NSURLRequest * _Nullable (^ _Nullable)(NSURLRequest * _Nullable newRequest))hiJackHandler completionHandler:(void (^ _Nonnull)(NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

@end
