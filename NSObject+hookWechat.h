//
//  NSObject+hookWechat.h
//  WechatPluginPro
//
//  Created by 刘伟 on 2017/11/29.
//  Copyright © 2017年 刘伟. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "SkingHelper.h"
#import "WCContactData.h"
#import "WXInterface.h"

@interface NSObject (hookWechat)

+ (void)readConfig;

//+ (void)hookWeChat;

@end





