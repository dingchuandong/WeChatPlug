//
//  ServerCallHelper.h
//  WechatPluginPro
//
//  Created by dcd on 2017/12/14.
//  Copyright © 2017年 刘伟. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WXInterface.h"
#import "WCContactData.h"
#import "UserInfo.h"

@interface ServerCallHelper : NSObject

//+ (ServerCallHelper *)shareServerCall;

//初始化其他通讯Queue
- (void)initQueue;

//自动回复
- (id)SendTextMessage:(id)arg1 toUsrName:(id)arg2 msgText:(id)arg3 atUserList:(id)arg4;

//自动邀请入群
- (BOOL)InviteGroupMemberWithChatRoomName:(NSString *)arg1 memberList:(NSArray *)arg2 completion:(id(^)(id))arg2block;

//自动拉入群
- (BOOL)AddGroupMembers:(NSArray *)arg1 withGroupUserName:(NSString *)arg2 completion:(id(^)(id))arg3;

//修改好友备注
- (BOOL)addOpLog_ModifyContact:(id)arg1 sync:(BOOL)arg2;

//修改群公告
- (void)setChatRoomAnnouncementWithUserName:(id)arg1 announceContent:(id)arg2 withCompletion:(id)arg3;

//发送图片消息
- (id)SendImgMessage:(id)arg1 toUsrName:(id)arg2 thumbImgData:(id)arg3 midImgData:(id)arg4 imgData:(id)arg5 imgInfo:(id)arg6;

- (void)SendImgMessage:(NSDictionary *)info;

@end


