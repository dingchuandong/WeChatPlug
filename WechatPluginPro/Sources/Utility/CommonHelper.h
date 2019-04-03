//
//  CommonHelper.h
//  WechatPluginPro
//
//  Created by boohee on 2018/5/17.
//  Copyright © 2018年 boohee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WCContactData.h"
#import "WXInterface.h"

@interface CommonHelper : NSObject

+(void)KillApp;

//主动获取用户全部信息
+(WCContactData *)getContactDataWithUserName:(NSString *)userName;

@end
