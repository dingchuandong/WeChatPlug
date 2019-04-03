//
//  CallServerHelper.h
//  WechatPluginPro
//
//  Created by dcd on 2017/12/14.
//  Copyright © 2017年 boohee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMQClient.h"

@interface IcelandClient : NSObject

@property (nonatomic, assign) BOOL isActiveQuit;//标识 主动退出

@property (nonatomic, strong) id<RMQChannel> clientChannel;
@property (nonatomic, strong) RMQQueue *qRCodeQ;//上传二维码
@property (nonatomic, strong) RMQQueue *allFriendQ;//全量联系人列表
@property (nonatomic, strong) RMQQueue *incrementalFriendQ;//增量上传联系人列表
@property (nonatomic, strong) RMQQueue *groupContactListQ;//群列表
@property (nonatomic, strong) RMQQueue *groupMemberListQ;//群成员列表
@property (nonatomic, strong) RMQQueue *whispersMessagesQ;//私聊消息
@property (nonatomic, strong) RMQQueue *messagesQ;//群消息
@property (nonatomic, strong) RMQQueue *offLineQ;//下线通知
@property (nonatomic, strong) RMQQueue *acceptFriendCallBackQ;//添加好友
@property (nonatomic, strong) RMQQueue *serverHeartbeatQ;//服务器心跳

@property (nonatomic, strong) dispatch_source_t timer,heartbeatTimer;
@property (nonatomic, strong) NSTimer *contactListTimer;

//接收到新消息
- (void)batchAddMsgs:(NSArray *)msgs isFirstSync:(BOOL)isFirstSync;

//获取群列表
- (void)getGroupContactList:(NSArray *)ary;

//获取联系人列表
- (void)getAllFriendContacts:(NSArray *)ary;

//获取登录的二维码
- (void)getQRCodeWithCompletion:(NSImage *)qrImage;

//收到好友请求
- (void)setFriendRequestData:(MMFriendRequestData *)friendRequestData;

// 主动调用微信自动通过好友成功
- (void)acceptFriendRequestWithFriendRequestData:(MMFriendRequestData *)friendRequestData completion:(id(^)(id))arg2block;

//用户状态发生改变
- (void)userStatusChanged;

//设置标识 上传服务器自己的信息
- (void)uploadUserInfo;

//处理上传语音逻辑
- (void)uploadVoice:(id)messageData andBeforeLength:(unsigned long long)length;

//上传图片逻辑
- (void)uploadImage:(MessageData *)messageData;

@end


