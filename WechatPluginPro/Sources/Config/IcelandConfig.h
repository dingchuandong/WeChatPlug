//
//  IcelandConfig.h
//  WechatPluginPro
//
//  Created by boohee on 2018/5/28.
//  Copyright © 2018年 boohee. All rights reserved.
//

typedef enum {
    ScanCode = 0,//扫描二维码优先
    ConfirmLogin,//表示确认登录优先
    AutoAuth//自动登录优先
} IceLandLoginType;

#import <Foundation/Foundation.h>
#import <DDLog.h>

@interface IcelandConfig : NSObject<DDRegisteredDynamicLogging>

//配置
@property (nonatomic, copy) NSString *AppSecret;
@property (nonatomic, copy) NSString *RabbitMQURL;
@property (nonatomic, copy) NSString *HttpURL;
//插件版本号
@property (nonatomic, copy) NSString *PluginVersion;
@property (nonatomic, copy) NSString *BotIdentity;
@property (nonatomic, copy) NSString *Host;
//是否允许多开
@property (nonatomic, copy) NSString *MultipleInstances;
//登录用户
@property (nonatomic, copy) NSString *UserName;
//取值 0，1 或 2，0 表示二维码登录优先，1 表示确认登录优先，2 表示自动登录优先，默认取 0
@property (nonatomic, assign) IceLandLoginType LoginType;

+ (IcelandConfig *)shareConfig;

@end
