//
//  UserInfo.m
//  WechatPluginPro
//
//  Created by dcd on 2017/12/18.
//  Copyright © 2017年 刘伟. All rights reserved.
//

#import "UserInfo.h"

@implementation UserInfo

+ (UserInfo *)shareUserInfo;
{
    static UserInfo* shareUserInfo = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareUserInfo = [[self alloc] init];
//
    });
    return shareUserInfo;
}

-(instancetype)init
{
    if (self=[super init]) {
        _groupMemberDic = [[NSMutableDictionary alloc] init];
        _groupContactDic = [[NSMutableDictionary alloc] init];
        _allFriendContactsDic = [[NSMutableDictionary alloc] init];
        
        //初值
        _AppSecret = @"jxuvrf4or8xfez2945o4om3vha7azsuz";
        _RabbitMQURL = @"https://iceberg-land.iboohee.cn/iceland/";
        _HttpURL =  @"amqp://bh_qa:boohee@192.168.1.45:5672";
    }
    return self;
}

////保存用户信息
//- (void)saveUserInfo:(NSString *)userName;
//{
//    if (userName) {
////        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:model];
//        [mUserDefaults setObject:userName forKey:KUserInfo];
//        [mUserDefaults synchronize];
//    }
//}
//
////获取用户信息
//- (NSString *)getInfo;
//{
//    if ([mUserDefaults objectForKey:KUserInfo]) {
//        return [mUserDefaults objectForKey:KUserInfo];
//    }
//    return @"";
//}
//
////保存用户信息（是否能自动添加好友）
//- (void)saveUserAccept:(BOOL)isAccept;
//{
//    if (isAccept) {
//        [mUserDefaults setBool:isAccept forKey:KIsAccept];
//        [mUserDefaults synchronize];
//    }
//}
//
////获取用户信息
//- (BOOL)getUserAccept;
//{
//    if ([mUserDefaults objectForKey:KIsAccept]) {
//        return [[mUserDefaults objectForKey:KIsAccept] boolValue];
//    }
//    return NO;
//}
//
////保存所有联系人
//- (void)saveAllFriendList:(NSDictionary *)ary;
//{
//    if (ary) {
//        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:ary];
//        [mUserDefaults setObject:data forKey:KAllFriend];
//        [mUserDefaults synchronize];
//    }
//}
//
////获取所有联系人信息
//- (NSDictionary *)getAllFriend;
//{
//    if ([mUserDefaults objectForKey:KAllFriend]) {
//        NSData *data = [mUserDefaults objectForKey:KAllFriend];
//        NSDictionary *ary = [NSKeyedUnarchiver unarchiveObjectWithData:data];
//        return ary;
//    }
//    return nil;
//}

@end
