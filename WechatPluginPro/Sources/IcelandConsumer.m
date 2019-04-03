//
//  ServerCallHelper.m
//  WechatPluginPro
//
//  Created by dcd on 2017/12/14.
//  Copyright © 2017年 boohee. All rights reserved.
//

#import "IcelandConsumer.h"
#import "RMQClient.h"
#import "CommonHelper.h"

@interface IcelandConsumer()

@property (nonatomic, strong) id<RMQChannel> consumerChannel;
@property (nonatomic, strong) RMQQueue *icelandInviteRoomCallBackQ;
@property (nonatomic, strong) RMQQueue *icelandSendMessageCallBackQ;

@end
@implementation IcelandConsumer

//初始化其他通讯Queue
- (void)initQueue;
{
    //接收数据
    RMQTLSOptions *tlsOptions = [RMQTLSOptions fromURI:[IcelandConfig shareConfig].RabbitMQURL verifyPeer:NO];
    RMQConnection *conn = [[RMQConnection alloc] initWithUri:[IcelandConfig shareConfig].RabbitMQURL tlsOptions:tlsOptions channelMax:@65535 frameMax:@131072 heartbeat:@0 syncTimeout:@30 delegate:[RMQConnectionDelegateLogger new] delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) recoverAfter:@4 recoveryAttempts:@(NSUIntegerMax) recoverFromConnectionClose:YES];
    self.consumerChannel = [conn createChannel];
    RMQExchange *exchang = [[RMQExchange alloc] initWithName:@"sneakers" type:@"direct" options:RMQExchangeDeclareDurable channel:self.consumerChannel];
    [conn start];
    
    //邀请入群回执
    self.icelandInviteRoomCallBackQ = [self.consumerChannel queue:@"iceberg.invite_room_callback" options:RMQQueueDeclareDurable];
    //转发消息回执
    self.icelandSendMessageCallBackQ = [self.consumerChannel queue:@"iceberg.send_message_callback" options:RMQQueueDeclareDurable];
    
    //是否能自动通过好友验证
    RMQQueue *isAcceptFriendQ = [self.consumerChannel queue:[NSString stringWithFormat:@"iceland.change_auto_accept_friend.%@",[UserInfo shareUserInfo].userName] options:RMQQueueDeclareDurable];
    [isAcceptFriendQ bind:exchang routingKey:isAcceptFriendQ.name];
    [isAcceptFriendQ subscribe:^(RMQMessage * _Nonnull message)
     {
         NSString *msg = [[NSString alloc] initWithData:message.body encoding:NSUTF8StringEncoding];
         NSDictionary *infoDic = [self dictionaryWithJsonString:msg];
         [UserInfo shareUserInfo].isAccept = [infoDic[@"data"][@"accept"] boolValue];
         DDLogInfo(@"服务器更改是否能自动通过好友验证，参数:\n%@",infoDic);
     }];
    
    //收到冰山发送的消息
    RMQQueue *sendTextQ = [self.consumerChannel queue:[NSString stringWithFormat:@"iceland.send_text.%@",[UserInfo shareUserInfo].userName] options:RMQQueueDeclareDurable];
    [sendTextQ bind:exchang routingKey:sendTextQ.name];
    [sendTextQ subscribe:^(RMQMessage * _Nonnull message)
     {
         NSString *msg = [[NSString alloc] initWithData:message.body encoding:NSUTF8StringEncoding];
         NSDictionary *infoDic = [self dictionaryWithJsonString:msg];
         infoDic = infoDic[@"data"];
         
         [self icelandSendTextMessage:infoDic];
         DDLogDebug(@"收到冰山发送的消息,参数:\n%@",[self dictionaryToJsonStr:infoDic]);
     }];
    
    //自动邀请入群
    RMQQueue *inviteGroupMemberQ = [self.consumerChannel queue:[NSString stringWithFormat:@"iceland.invite_room.%@",[UserInfo shareUserInfo].userName] options:RMQQueueDeclareDurable];
    [inviteGroupMemberQ bind:exchang routingKey:inviteGroupMemberQ.name];
    [inviteGroupMemberQ subscribe:^(RMQMessage * _Nonnull message)
     {
         NSString *msg = [[NSString alloc] initWithData:message.body encoding:NSUTF8StringEncoding];
         NSDictionary *infoDic = [self dictionaryWithJsonString:msg];
         infoDic = infoDic[@"data"];
         NSArray *userAry = [[NSArray alloc] initWithArray:infoDic[@"user_names"]];
         NSMutableArray *newUserAry = [[NSMutableArray alloc] init];
         for (NSString *str in userAry) {
             GroupMember *newmember = [[objc_getClass("GroupMember") alloc] init];
             newmember.m_uiMemberStatus = 0;
             newmember.m_nsMemberName = str;
             newmember.m_nsNickName = nil;
             [newUserAry addObject:newmember];
         }
         
         BOOL issuccess;
         GroupStorage *groupS = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("GroupStorage")];
         NSArray *ary = [groupS GetGroupMemberListWithGroupUserName:infoDic[@"room_user_name"]];
         //大于40 拉群方式不同
         if (ary.count >= 40) {
             id com;
             issuccess = [self inviteGroupMemberWithChatRoomName:infoDic[@"room_user_name"] memberList:newUserAry completion:com];
         }else{
             issuccess = [self addGroupMembers:newUserAry withGroupUserName:infoDic[@"room_user_name"] completion:nil];
         }
         //通知服务器
         [self inviteRoomCallBackUserName:userAry andRoomUserName:infoDic[@"room_user_name"] andSuccess:issuccess];
         DDLogInfo(@"（自动邀请入群）参数:\n%@",[self dictionaryToJsonStr:infoDic]);
     }];
    
    //修改好友备注
    RMQQueue *changeUserNameQ = [self.consumerChannel queue:[NSString stringWithFormat:@"iceland.remark_name.%@",[UserInfo shareUserInfo].userName] options:RMQQueueDeclareDurable];
    [changeUserNameQ bind:exchang routingKey:changeUserNameQ.name];
    [changeUserNameQ subscribe:^(RMQMessage * _Nonnull message)
     {
         NSString *msg = [[NSString alloc] initWithData:message.body encoding:NSUTF8StringEncoding];
         NSDictionary *infoDic = [self dictionaryWithJsonString:msg];
         infoDic = infoDic[@"data"];
         //主动获取
         WCContactData *contactData = [CommonHelper getContactDataWithUserName:infoDic[@"user_name"]];
         if (contactData) {
             contactData.m_nsRemark = infoDic[@"remark_name"];
             [self addOpLog_ModifyContact:contactData sync:1];
             DDLogInfo(@"（修改好友备注),参数:\n%@",[self dictionaryToJsonStr:infoDic]);
         }
     }];
    
    //修改群公告
    RMQQueue *changeChatRoomQ = [self.consumerChannel queue:[NSString stringWithFormat:@"iceland.room_broadcast.%@",[UserInfo shareUserInfo].userName] options:RMQQueueDeclareDurable];
    [changeChatRoomQ bind:exchang routingKey:changeChatRoomQ.name];
    [changeChatRoomQ subscribe:^(RMQMessage * _Nonnull message)
     {
         NSString *msg = [[NSString alloc] initWithData:message.body encoding:NSUTF8StringEncoding];
         NSDictionary *infoDic = [self dictionaryWithJsonString:msg];
         infoDic = infoDic[@"data"];
         [self setChatRoomAnnouncementWithUserName:infoDic[@"user_name"] announceContent:infoDic[@"content"] withCompletion:nil];
         DDLogInfo(@"（修改群公告）,参数:\n%@",[self dictionaryToJsonStr:infoDic]);
     }];
    
    //发送图片消息
    RMQQueue *sendImgQ = [self.consumerChannel queue:[NSString stringWithFormat:@"iceland.send_image.%@",[UserInfo shareUserInfo].userName] options:RMQQueueDeclareDurable];
    [sendImgQ bind:exchang routingKey:sendImgQ.name];
    [sendImgQ subscribe:^(RMQMessage * _Nonnull message)
     {
         NSString *msg = [[NSString alloc] initWithData:message.body encoding:NSUTF8StringEncoding];
         NSDictionary *infoDic = [self dictionaryWithJsonString:msg];
         infoDic = infoDic[@"data"];
         [self sendImgMessage:infoDic];
         DDLogDebug(@"收到冰山发送的图片消息,参数:\n%@",[self dictionaryToJsonStr:infoDic]);
     }];
    
    //踢人
    RMQQueue *removeMembersQ = [self.consumerChannel queue:[NSString stringWithFormat:@"iceland.remove_members.%@",[UserInfo shareUserInfo].userName] options:RMQQueueDeclareDurable];
    [removeMembersQ bind:exchang routingKey:removeMembersQ.name];
    [removeMembersQ subscribe:^(RMQMessage * _Nonnull message)
     {
         NSString *msg = [[NSString alloc] initWithData:message.body encoding:NSUTF8StringEncoding];
         NSDictionary *infoDic = [self dictionaryWithJsonString:msg];
         infoDic = infoDic[@"data"];
         if(infoDic)
         {
             NSString *roomUserName = infoDic[@"room_user_name"];
             NSArray *userNameAry = [[NSArray alloc] initWithArray:infoDic[@"user_names"]];
             [self deleteGroupMemberWithGroupUserName:roomUserName memberUserNameList:userNameAry completion:nil];
         }
         DDLogInfo(@"（踢人）,参数:\n%@",[self dictionaryToJsonStr:infoDic]);
     }];
    
    //消息已读
    RMQQueue *readChatQ = [self.consumerChannel queue:[NSString stringWithFormat:@"iceland.read_chat.%@",[UserInfo shareUserInfo].userName] options:RMQQueueDeclareDurable];
    [readChatQ bind:exchang routingKey:readChatQ.name];
    [readChatQ subscribe:^(RMQMessage * _Nonnull message)
     {
         NSString *msg = [[NSString alloc] initWithData:message.body encoding:NSUTF8StringEncoding];
         NSDictionary *infoDic = [self dictionaryWithJsonString:msg];
         infoDic = infoDic[@"data"];
         if(infoDic)
         {
             NSString *roomUserName = infoDic[@"user_name"];
             [self readChatWithGroupUserName:roomUserName];
         }
         DDLogDebug(@"(消息置已读),参数:\n%@",[self dictionaryToJsonStr:infoDic]);
     }];
    
    //服务器通知下线
    RMQQueue *offLineQ = [self.consumerChannel queue:[NSString stringWithFormat:@"iceland.offline.%@",[UserInfo shareUserInfo].userName] options:RMQQueueDeclareDurable];
    [offLineQ bind:exchang routingKey:offLineQ.name];
    [offLineQ subscribe:^(RMQMessage * _Nonnull message)
     {
         NSString *msg = [[NSString alloc] initWithData:message.body encoding:NSUTF8StringEncoding];
         NSDictionary *infoDic = [self dictionaryWithJsonString:msg];
         infoDic = infoDic[@"data"];
         if ([infoDic[@"offline"] isEqualToString:@"1"]) {
             DDLogInfo(@"进程被终止了 （服务器通知下线）");
             [CommonHelper KillApp];
         }
     }];
}

//通知服务器 邀请群消息发送成功
- (void)inviteRoomCallBackUserName:(NSArray *)names andRoomUserName:(NSString *)roomUserName andSuccess:(BOOL)issuccess
{
    NSDictionary *offlineDic = [[NSDictionary alloc] initWithObjectsAndKeys:issuccess?@"true":@"false",@"success",names,@"user_names",roomUserName,@"room_user_name", nil];
    NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:offlineDic,@"payload",[UserInfo shareUserInfo].userName,@"user_name", nil];
    [self.consumerChannel.defaultExchange publish:[self dictionaryToJson:dic] routingKey:self.icelandInviteRoomCallBackQ.name];
}

//回复消息
- (void)icelandSendTextMessage:(NSDictionary *)infoDic;
{
    if (infoDic[@"user_name"] && infoDic[@"content"]) {
        NSString *currentUserName = [NSString stringWithFormat:@"%@",[objc_getClass("CUtility") GetCurrentUserName]];
        MessageService *msgService = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("MessageService")];
        MessageData *messageData = [msgService SendTextMessage:currentUserName toUsrName:infoDic[@"user_name"] msgText:infoDic[@"content"] atUserList:infoDic[@"at_user_names"]];
        if (messageData) {
            [self messageSendSuccessCallBack:infoDic[@"ice_message_id"]];
        }
    }
}

//自动邀请入群
- (BOOL)inviteGroupMemberWithChatRoomName:(NSString *)arg1 memberList:(NSArray *)arg2 completion:(id(^)(id))arg2block;
{
    GroupStorage *groupStorage = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("GroupStorage")];
     return [groupStorage InviteGroupMemberWithChatRoomName:arg1 memberList:arg2 completion:arg2block];
}

//自动拉入群
- (BOOL)addGroupMembers:(NSArray *)arg1 withGroupUserName:(NSString *)arg2 completion:(id(^)(id))arg3;
{
    GroupStorage *groupStorage = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("GroupStorage")];
    return [groupStorage AddGroupMembers:arg1 withGroupUserName:arg2 completion:arg3];
}

//修改好友备注
- (BOOL)addOpLog_ModifyContact:(id)arg1 sync:(BOOL)arg2;
{
    ContactStorage *contactStorage = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("ContactStorage")];
    [contactStorage addOpLog_ModifyContact:arg1 sync:arg2];
    return YES;
}

//修改群公告
- (void)setChatRoomAnnouncementWithUserName:(id)arg1 announceContent:(id)arg2 withCompletion:(id)arg3;
{
    MMChatRoomInfoDetailCGI *chatsRoomDetail = [[objc_getClass("MMChatRoomInfoDetailCGI") alloc] init];
    [chatsRoomDetail setChatRoomAnnouncementWithUserName:arg1 announceContent:arg2 withCompletion:arg3];
}

//处理服务器 发送过来的图片
- (void)sendImgMessage:(NSDictionary *)infoDic
{
    NSString *toUserName = infoDic[@"user_name"];
    NSString *imgUrl = infoDic[@"image_url"];
    
//    NSString *toUserName = @"dcd_314";
//    NSString *imgUrl = @"http://oc1jw3mv7.bkt.clouddn.com/50KPNG.png";
    
    if (imgUrl == nil || toUserName == nil) {
        return;
    }

    NSBitmapImageFileType type;
    if ([imgUrl containsString:@".png"]) {
        type = NSBitmapImageFileTypePNG;
    }else{
        type = NSBitmapImageFileTypeJPEG;
    }

    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:imgUrl]]];
    //图片质量
    NSNumber *quality = [NSNumber numberWithFloat:1.0];
    NSDictionary *imageProps = [NSDictionary dictionaryWithObject:quality forKey:NSImageCompressionFactor];
    NSData *imageData = [imageRep representationUsingType:type properties:imageProps];
    NSImage *image = [[NSImage alloc] initWithData:imageData];
    __block NSData *midData;
    NSData * thumbData;
    
    NSString *currentUserName = [NSString stringWithFormat:@"%@",[objc_getClass("CUtility") GetCurrentUserName]];
    SendImageInfo *imgInfo = [[objc_getClass("SendImageInfo") alloc] init];
    
    if (imageData.length/1024 < 11) {
        thumbData = imageData;
        NSImage *thumbImg = [[NSImage alloc] initWithData:thumbData];
        imgInfo.m_uiThumbWidth = thumbImg.size.width;
        imgInfo.m_uiThumbHeight = thumbImg.size.height;
        imgInfo.m_uiOriginalHeight = image.size.height;
        imgInfo.m_uiOriginalWidth = image.size.width;
        [self sendImgMessage:currentUserName toUsrName:toUserName thumbImgData:thumbData midImgData:midData imgData:imageData imgInfo:imgInfo icelandMessageID:infoDic[@"ice_message_id"]];
    }else if (imageData.length/1024 < 100)
    {

//        thumbData = [self compressOriginalImage:image toMaxDataSizeKBytes:11];
        MessageThumbData *result = image.thumbnailDataForMessage;
        thumbData = result.data;
        NSImage *thumbImg = [[NSImage alloc] initWithData:thumbData];
        imgInfo.m_uiThumbWidth = thumbImg.size.width;
        imgInfo.m_uiThumbHeight = thumbImg.size.height;
        imgInfo.m_uiOriginalHeight = image.size.height;
        imgInfo.m_uiOriginalWidth = image.size.width;
        [self sendImgMessage:currentUserName toUsrName:toUserName thumbImgData:thumbData midImgData:midData imgData:imageData imgInfo:imgInfo icelandMessageID:infoDic[@"ice_message_id"]];
    }else
    {
//        midData = [self compressOriginalImage:image toMaxDataSizeKBytes:77];
//        thumbData = [self compressOriginalImage:image toMaxDataSizeKBytes:11];
        
        MessageThumbData *result = image.thumbnailDataForMessage;
        thumbData = result.data;
        [image middleImageDataWithCompletion:^(id argarg1) {
            midData = argarg1;
            NSImage *thumbImg = [[NSImage alloc] initWithData:thumbData];
            imgInfo.m_uiThumbWidth = thumbImg.size.width;
            imgInfo.m_uiThumbHeight = thumbImg.size.height;
            imgInfo.m_uiOriginalHeight = image.size.height;
            imgInfo.m_uiOriginalWidth = image.size.width;
            [self sendImgMessage:currentUserName toUsrName:toUserName thumbImgData:thumbData midImgData:midData imgData:imageData imgInfo:imgInfo icelandMessageID:infoDic[@"ice_message_id"]];
        }];
    }
}

//发送图片消息
- (void)sendImgMessage:(id)arg1 toUsrName:(id)arg2 thumbImgData:(id)arg3 midImgData:(id)arg4 imgData:(id)arg5 imgInfo:(id)arg6 icelandMessageID:(NSString *)icelandMessageID;
{
    MessageService *msgService = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("MessageService")];
    MessageData *messageData = [msgService SendImgMessage:arg1 toUsrName:arg2 thumbImgData:arg3 midImgData:arg4 imgData:arg5 imgInfo:arg6];
    if (messageData) {
        [self messageSendSuccessCallBack:icelandMessageID];
    }
}

/**
 踢人
 **/
- (void)deleteGroupMemberWithGroupUserName:(id)arg1 memberUserNameList:(id)arg2 completion:(id)arg3
{
    GroupStorage *groupS = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("GroupStorage")];
    [groupS DeleteGroupMemberWithGroupUserName:arg1 memberUserNameList:arg2 completion:arg3];
}

/**
 消息已读
 **/
- (void)readChatWithGroupUserName:(NSString *)userName
{
    //模拟微信点击 必须在主线程执行
    if ([NSThread isMainThread]){
        WeChat *wechat = [objc_getClass("WeChat") sharedInstance];
        [wechat.chatsViewController selectChatWithUserName:userName];
    }else{
        dispatch_sync(dispatch_get_main_queue(), ^{
            //Update UI in UI thread here
            WeChat *wechat = [objc_getClass("WeChat") sharedInstance];
            [wechat.chatsViewController selectChatWithUserName:userName];
        });
    }
}

/**
 消息转发成功 回执
 **/
- (void)messageSendSuccessCallBack:(NSString *)icelandMessageID
{
    NSMutableDictionary *infoDic = [[NSMutableDictionary alloc] init];
    [infoDic setObject:icelandMessageID forKey:@"ice_message_id"];
    NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:infoDic,@"payload",[UserInfo shareUserInfo].userName,@"user_name", nil];
    [self.consumerChannel.defaultExchange publish:[self dictionaryToJson:dic] routingKey:self.icelandSendMessageCallBackQ.name];
    DDLogDebug(@"消息转发成功 回执 参数：\n %@",[self dictionaryToJson:dic]);
}

//json格式字符串转字典：
- (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString
{
    if (jsonString == nil) {
        return nil;
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err) {
        DDLogError(@"json解析失败：原因：%@ 转换前：%@",err,jsonString);
        return nil;
    }
    return dic;
}


//字典转data：
- (NSData*)dictionaryToJson:(NSDictionary *)dic
{
    //NSJSONWritingPrettyPrinted  是有换位符的。
    //如果NSJSONWritingPrettyPrinted 是nil 的话 返回的数据是没有 换位符的
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    return jsonData;
    //    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

//字典转json格式字符串：
- (NSString *)dictionaryToJsonStr:(NSDictionary *)dic
{
    //NSJSONWritingPrettyPrinted  是有换位符的。
    //如果NSJSONWritingPrettyPrinted 是nil 的话 返回的数据是没有 换位符的
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}
@end
