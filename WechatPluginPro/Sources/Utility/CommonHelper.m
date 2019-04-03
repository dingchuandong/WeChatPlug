//
//  CommonHelper.m
//  WechatPluginPro
//
//  Created by boohee on 2018/5/17.
//  Copyright © 2018年 boohee. All rights reserved.
//

#import "CommonHelper.h"
#import <AppKit/AppKit.h>

@implementation CommonHelper

//安全杀死进程
+(void)KillApp
{
    DDLogInfo(@"[NSApp terminate:nil]");
    [NSApp terminate:nil];
    DDLogInfo(@"terminate 执行失败");
    //五秒后进程还存在直接退出
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DDLogInfo(@"exit(0)");
        exit(0);
        DDLogInfo(@"exit(0)  执行失败   进程没有杀死");
    });
}

//主动获取用户全部信息
+(WCContactData *)getContactDataWithUserName:(NSString *)userName;
{
    MMSessionMgr *sessionMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("MMSessionMgr")];
    WCContactData *msgContact = [sessionMgr getContact:userName];
    return msgContact;
}

@end
