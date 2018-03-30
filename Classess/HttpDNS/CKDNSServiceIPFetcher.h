//
//  CKDNSServiceIPFetcher.h
//  CompassKit
//
//  Created by darren.huang on 23/03/2018.
//  Copyright © 2018 Keeping. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

typedef void(^CKServiceIPFetcheCompletionHandler)(NSDictionary *DNSDictionary);

@interface CKDNSServiceIPFetcher : NSObject
+ (instancetype)shareFetcher;
- (void)fetchServiceIPByArea:(NSString *)area
                     domains:(NSArray *)domainArray
                       token:(NSString *)token
                     project:(NSString *)project
           completionHandler:(nonnull CKServiceIPFetcheCompletionHandler)handler;

@end
NS_ASSUME_NONNULL_END
