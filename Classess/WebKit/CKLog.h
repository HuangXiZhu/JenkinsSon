//
//  CKLog.h
//  CompassKit
//
//  Created by syosan on 2016/10/27.
//  Copyright © 2016年 Keeping. All rights reserved.
//

#ifndef CKLog_h
#define CKLog_h

extern BOOL CKConfigurationDebug;
#define CKLog(fmt, ...)  if(CKConfigurationDebug)NSLog((@"[XKit] %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#define NGPLog(FORMAT, ...) if(CKConfigurationDebug)fprintf(stderr,"%s\n",[[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);

#endif /* CKLog_h */
