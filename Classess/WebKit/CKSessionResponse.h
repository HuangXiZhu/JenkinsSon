//
//  CKSession.h
//  CompassKit
//
//  Created by syosan on 2017/3/5.
//  Copyright © 2017年 Keeping. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CKSessionResponseDelegate;

@interface CKSessionResponse : NSObject <NSURLSessionDataDelegate>

+ (nonnull CKSessionResponse *)get;
+ (void)add:(id<CKSessionResponseDelegate> _Nullable)delegate;
+ (void)remove:(id<CKSessionResponseDelegate> _Nullable)delegate;
@end

@protocol CKSessionResponseDelegate <NSObject>

@optional
- (void)URLSession:(nonnull NSURLSession *)session dataTask:(nonnull NSURLSessionDataTask *)dataTask didReceiveData:(nullable NSData *)data;
- (void)URLSession:(nonnull NSURLSession *)session task:(nonnull NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error;

@end
