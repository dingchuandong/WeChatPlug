//
//  UserInfo.m
//  WechatPluginPro
//
//  Created by dcd on 2017/12/18.
//  Copyright © 2017年 boohee. All rights reserved.
//

#import "UserInfo.h"

@implementation UserInfo

+ (UserInfo *)shareUserInfo;
{
    static UserInfo *shareUserInfo = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareUserInfo = [[self alloc] init];
    });
    return shareUserInfo;
}

-(instancetype)init
{
    if (self = [super init]) {
        _groupContactSet = [[NSMutableSet alloc] init];
        _allFriendContactsSet = [[NSMutableSet alloc] init];
    }
    return self;
}

@end
