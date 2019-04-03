//
//  UserInfo.h
//  WechatPluginPro
//
//  Created by dcd on 2017/12/18.
//  Copyright © 2017年 刘伟. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UserInfo : NSObject

@property (nonatomic, strong) NSMutableDictionary *groupMemberDic,*groupContactDic,*allFriendContactsDic;
@property (nonatomic, copy) NSString *userName;
@property (nonatomic, assign) BOOL isAccept;

//配置
@property (nonatomic, copy) NSString *AppSecret;
@property (nonatomic, copy) NSString *RabbitMQURL;
@property (nonatomic, copy) NSString *HttpURL;


+ (UserInfo *)shareUserInfo;

////保存用户信息
//- (void)saveUserInfo:(NSString *)userName;
//
////获取用户信息
//- (NSString *)getInfo;
//
////保存用户信息（是否能自动添加好友）
//- (void)saveUserAccept:(BOOL)isAccept;
//
////获取用户信息
//- (BOOL)getUserAccept;
//
////保存所有联系人
//- (void)saveAllFriendList:(NSDictionary *)ary;
//
////获取所有联系人信息
//- (NSDictionary *)getAllFriend;



@end
