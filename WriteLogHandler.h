//
//  WriteLogHandler.h
//  WechatPluginPro
//
//  Created by dcd on 2018/1/11.
//  Copyright © 2018年 刘伟. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WriteLogHandler : NSObject

+ (WriteLogHandler *)shareLogHander;

- (void)writefile:(NSString *)infoStr;

@end
