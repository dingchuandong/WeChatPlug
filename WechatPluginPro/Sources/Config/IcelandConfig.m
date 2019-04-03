//
//  IcelandConfig.m
//  WechatPluginPro
//
//  Created by boohee on 2018/5/28.
//  Copyright © 2018年 boohee. All rights reserved.
//

#import "IcelandConfig.h"

//日志等级
static DDLogLevel ddLogLevel = DDLogLevelInfo;

@implementation IcelandConfig

+ (IcelandConfig *)shareConfig;
{
    static IcelandConfig *shareConfig = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareConfig = [[self alloc] init];
    });
    return shareConfig;
}

-(instancetype)init
{
    if (self = [super init]) {
        //初值
        _AppSecret = @"jxuvrf4or8xfez2945o4om3vha7azsuz";
        _PluginVersion = @"1.2.2";
        _BotIdentity = @"dcd";
        _Host = @"dcd";
        _MultipleInstances = @"1";
        _UserName = @"wxid_o9hefnqeks3722";//小香蕉
        _LoginType = ScanCode;
        _RabbitMQURL = @"amqp://bh_qa:boohee@192.168.1.45:5672";
        _HttpURL =  @"https://ice.iboohee.cn/iceland/";
        
        //路行
//        _LoginType = AutoAuth;
//        _RabbitMQURL = @"amqp://lux:oooppp@192.168.9.31:5672";
//        _HttpURL =  @"http://192.168.9.31:3000/iceland/";
    }
    return self;
}

//日志等级
+ (DDLogLevel)ddLogLevel {
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(DDLogLevel)level {
    ddLogLevel = level;
}

@end
