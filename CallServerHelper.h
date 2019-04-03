//
//  CallServerHelper.h
//  WechatPluginPro
//
//  Created by dcd on 2017/12/14.
//  Copyright © 2017年 刘伟. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WXInterface.h"
#import "WCContactData.h"
#import "RMQClient.h"
#import "UserInfo.h"

static NSMutableDictionary *groupMemberDic,*groupContactDic,*allFriendContactsDic;

@interface CallServerHelper : NSObject

@property (nonatomic, assign) BOOL isFinishedLoad;//标识 用户数据 及 群数据已经加载完成
@property (nonatomic, assign) BOOL isActiveQuit;//标识 主动退出

@property (nonatomic, strong) id<RMQChannel> ch;
@property (nonatomic, strong) RMQQueue *QRCodeQ;//上传二维码
@property (nonatomic, strong) RMQQueue *AllFriendQ;//联系人列表
@property (nonatomic, strong) RMQQueue *GroupContactListQ;//群列表
@property (nonatomic, strong) RMQQueue *GroupMemberListQ;//群成员列表
@property (nonatomic, strong) RMQQueue *WhispersMessagesQ;//私聊消息
@property (nonatomic, strong) RMQQueue *MessagesQ;//群消息
@property (nonatomic, strong) RMQQueue *OffLineQ;//下线通知
@property (nonatomic, strong) RMQQueue *AcceptFriendCallBackQ;//添加好友
@property (nonatomic, strong) RMQQueue *ServerHeartbeatQ;//服务器心跳

@property (nonatomic, strong) dispatch_source_t timer,heartbeatTimer;
@property (nonatomic, strong) NSTimer *contactListTimer;

//发送消息
- (void)SendTextMessage:(id)arg1 toUsrName:(id)arg2 msgText:(id)arg3 atUserList:(id)arg4;

//接收到新消息
- (void)BatchAddMsgs:(NSArray *)msgs isFirstSync:(BOOL)arg2;

//获取群成员列表
- (void)GetGroupMemberListWithGroupUserName:(NSArray *)ary andGroupID:(NSString *)groupIDStr;

//获取群列表
- (void)GetGroupContactList:(NSArray *)ary;

//获取联系人列表
- (void)GetAllFriendContacts:(NSArray *)ary;

//获取登录的二维码
- (void)GetQRCodeWithCompletion:(NSImage *)arg1;

//收到好友请求
- (void)InitWithDictionary:(id)arg1;

// 拦截确认好友方法
- (id)AcceptFriendRequestWithFriendRequestData:(MMFriendRequestData *)arg1 completion:(id(^)(id))arg2block;

//用户状态发生改变
- (void)StartNotifier:(BOOL)arg1;

//设置标识 上传服务器自己的信息
- (void)setisFinishedLoad: (BOOL)arg1;

@end


