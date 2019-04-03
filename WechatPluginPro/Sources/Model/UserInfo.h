//
//  UserInfo.h
//  WechatPluginPro
//
//  Created by dcd on 2017/12/18.
//  Copyright © 2017年 boohee. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UserInfo : NSObject

@property (nonatomic, copy) NSString *userName;
@property (nonatomic, assign) BOOL isAccept;
@property (nonatomic, strong) NSMutableSet *allFriendContactsSet;
@property (nonatomic, strong) NSMutableSet *groupContactSet;

+ (UserInfo *)shareUserInfo;

@end
