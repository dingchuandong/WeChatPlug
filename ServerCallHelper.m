//
//  ServerCallHelper.m
//  WechatPluginPro
//
//  Created by dcd on 2017/12/14.
//  Copyright © 2017年 刘伟. All rights reserved.
//

#import "ServerCallHelper.h"
#import "RMQClient.h"
#import "WriteLogHandler.h"

@implementation ServerCallHelper


//初始化其他通讯Queue
- (void)initQueue;
{
    //接收数据
    __block RMQConnection *conn;
    __block id<RMQChannel> ch;
    __block RMQExchange *exchang;
    
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        conn = [[RMQConnection alloc] initWithUri:[UserInfo shareUserInfo].RabbitMQURL delegate:[RMQConnectionDelegateLogger new]];
    RMQTLSOptions *tlsOptions = [RMQTLSOptions fromURI:[UserInfo shareUserInfo].RabbitMQURL verifyPeer:NO];

    conn = [[RMQConnection alloc] initWithUri:[UserInfo shareUserInfo].RabbitMQURL tlsOptions:tlsOptions channelMax:@65535 frameMax:@131072 heartbeat:@0 syncTimeout:@30 delegate:[RMQConnectionDelegateLogger new] delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) recoverAfter:@4 recoveryAttempts:@(NSUIntegerMax) recoverFromConnectionClose:YES];
        ch = [conn createChannel];
        exchang = [[RMQExchange alloc] initWithName:@"sneakers" type:@"direct" options:RMQExchangeDeclareDurable channel:ch];
//    });
    
    [conn start];

    //是否能自动通过好友验证
    RMQQueue *isAcceptFriendQ = [ch queue:[NSString stringWithFormat:@"iceland.change_auto_accept_friend.%@",[UserInfo shareUserInfo].userName] options:RMQQueueDeclareDurable];
    [isAcceptFriendQ bind:exchang routingKey:isAcceptFriendQ.name];
    [isAcceptFriendQ subscribe:^(RMQMessage * _Nonnull message)
     {
         NSString *msg = [[NSString alloc] initWithData:message.body encoding:NSUTF8StringEncoding];
         NSDictionary *infoDic = [self dictionaryWithJsonString:msg];
         [UserInfo shareUserInfo].isAccept = [infoDic[@"data"][@"accept"] boolValue];
     }];
    
    //自动回复
    RMQQueue *SendTextQ = [ch queue:[NSString stringWithFormat:@"iceland.send_text.%@",[UserInfo shareUserInfo].userName] options:RMQQueueDeclareDurable];
    [SendTextQ bind:exchang routingKey:SendTextQ.name];
    [SendTextQ subscribe:^(RMQMessage * _Nonnull message)
     {
         NSString *msg = [[NSString alloc] initWithData:message.body encoding:NSUTF8StringEncoding];
         NSDictionary *infoDic = [self dictionaryWithJsonString:msg];
         infoDic = infoDic[@"data"];
         
         [self SendTextMessage:nil toUsrName:infoDic[@"user_name"] msgText:infoDic[@"content"] atUserList:infoDic[@"at_user_names"]];
         //记录日志
         [[WriteLogHandler shareLogHander] writefile:[NSString stringWithFormat:@"方法名:%s,参数:%@",__func__,[self dictionaryToJsonStr:infoDic]]];
     }];
    
    //自动邀请入群
    RMQQueue *InviteGroupMemberQ = [ch queue:[NSString stringWithFormat:@"iceland.invite_room.%@",[UserInfo shareUserInfo].userName] options:RMQQueueDeclareDurable];
    [InviteGroupMemberQ bind:exchang routingKey:InviteGroupMemberQ.name];
    [InviteGroupMemberQ subscribe:^(RMQMessage * _Nonnull message)
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
//         NSArray *numberAry = [[UserInfo shareUserInfo].groupMemberDic objectForKey:infoDic[@"room_user_name"]];
         GroupStorage *groupS = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("GroupStorage")];
         NSArray *ary = [groupS GetGroupMemberListWithGroupUserName:infoDic[@"room_user_name"]];
         //大于40 拉群方式不同
         if (ary.count >= 40) {
             id com;
             issuccess = [self InviteGroupMemberWithChatRoomName:infoDic[@"room_user_name"] memberList:newUserAry completion:com];
         }else{
             issuccess = [self AddGroupMembers:newUserAry withGroupUserName:infoDic[@"room_user_name"] completion:nil];
         }
         //通知服务器
         [self InviteRoomCallBackUserName:userAry andRoomUserName:infoDic[@"room_user_name"] andSuccess:issuccess];
         
         //记录日志
         [[WriteLogHandler shareLogHander] writefile:[NSString stringWithFormat:@"方法名:%s,参数:%@",__func__,[self dictionaryToJsonStr:infoDic]]];
     }];
    
    //修改好友备注
    RMQQueue *ChangeUserNameQ = [ch queue:[NSString stringWithFormat:@"iceland.remark_name.%@",[UserInfo shareUserInfo].userName] options:RMQQueueDeclareDurable];
    [ChangeUserNameQ bind:exchang routingKey:ChangeUserNameQ.name];
    [ChangeUserNameQ subscribe:^(RMQMessage * _Nonnull message)
     {
         NSString *msg = [[NSString alloc] initWithData:message.body encoding:NSUTF8StringEncoding];
         NSDictionary *infoDic = [self dictionaryWithJsonString:msg];
         infoDic = infoDic[@"data"];
         //从本地取
         WCContactData *contactData = [UserInfo shareUserInfo].allFriendContactsDic[infoDic[@"user_name"]];
         contactData.m_nsRemark = infoDic[@"remark_name"];
         [self addOpLog_ModifyContact:contactData sync:1];
         
         //记录日志
         [[WriteLogHandler shareLogHander] writefile:[NSString stringWithFormat:@"方法名:%s,参数:%@",__func__,[self dictionaryToJsonStr:infoDic]]];
     }];
    
    //修改群公告
    RMQQueue *ChangeChatRoomQ = [ch queue:[NSString stringWithFormat:@"iceland.room_broadcast.%@",[UserInfo shareUserInfo].userName] options:RMQQueueDeclareDurable];
    [ChangeChatRoomQ bind:exchang routingKey:ChangeChatRoomQ.name];
    [ChangeChatRoomQ subscribe:^(RMQMessage * _Nonnull message)
     {
         NSString *msg = [[NSString alloc] initWithData:message.body encoding:NSUTF8StringEncoding];
         NSDictionary *infoDic = [self dictionaryWithJsonString:msg];
         infoDic = infoDic[@"data"];
         [self setChatRoomAnnouncementWithUserName:infoDic[@"user_name"] announceContent:infoDic[@"content"] withCompletion:nil];
         
         //记录日志
         [[WriteLogHandler shareLogHander] writefile:[NSString stringWithFormat:@"方法名:%s,参数:%@",__func__,[self dictionaryToJsonStr:infoDic]]];
     }];
    
    //发送图片消息
    RMQQueue *SendImgQ = [ch queue:[NSString stringWithFormat:@"iceland.send_image.%@",[UserInfo shareUserInfo].userName] options:RMQQueueDeclareDurable];
    [SendImgQ bind:exchang routingKey:SendImgQ.name];
    [SendImgQ subscribe:^(RMQMessage * _Nonnull message)
     {
         NSString *msg = [[NSString alloc] initWithData:message.body encoding:NSUTF8StringEncoding];
         NSDictionary *infoDic = [self dictionaryWithJsonString:msg];
         infoDic = infoDic[@"data"];
         [self SendImgMessage:infoDic];
         
         //记录日志
         [[WriteLogHandler shareLogHander] writefile:[NSString stringWithFormat:@"方法名:%s,参数:%@",__func__,[self dictionaryToJsonStr:infoDic]]];
     }];
    
    //服务器通知下线
    RMQQueue *OffLineQ = [ch queue:[NSString stringWithFormat:@"iceland.offline.%@",[UserInfo shareUserInfo].userName] options:RMQQueueDeclareDurable];
    [OffLineQ bind:exchang routingKey:OffLineQ.name];
    [OffLineQ subscribe:^(RMQMessage * _Nonnull message)
     {
         NSString *msg = [[NSString alloc] initWithData:message.body encoding:NSUTF8StringEncoding];
         NSDictionary *infoDic = [self dictionaryWithJsonString:msg];
         infoDic = infoDic[@"data"];
         if ([infoDic[@"offline"] isEqualToString:@"1"]) {
             //杀死进程
             [[WriteLogHandler shareLogHander] writefile:[NSString stringWithFormat:@"进程被kill了 方法名：%s",__func__]];
             abort();
         }
     }];
    
    //日志
    [[WriteLogHandler shareLogHander] writefile:[NSString stringWithFormat:@"方法名：%s\n行数：%s",__func__,__FILE__]];

}

//通知服务器 邀请群消息发送成功
- (void)InviteRoomCallBackUserName:(NSArray *)names andRoomUserName:(NSString *)roomUserName andSuccess:(BOOL)issuccess
{
    RMQTLSOptions *tlsOptions = [RMQTLSOptions fromURI:[UserInfo shareUserInfo].RabbitMQURL verifyPeer:NO];
    
    RMQConnection *conn = [[RMQConnection alloc] initWithUri:[UserInfo shareUserInfo].RabbitMQURL tlsOptions:tlsOptions channelMax:@65535 frameMax:@131072 heartbeat:@0 syncTimeout:@30 delegate:[RMQConnectionDelegateLogger new] delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) recoverAfter:@4 recoveryAttempts:@(NSUIntegerMax) recoverFromConnectionClose:YES];
    id<RMQChannel> ch = [conn createChannel];
//    RMQExchange *exchang = [[RMQExchange alloc] initWithName:@"sneakers" type:@"direct" options:RMQExchangeDeclareDurable channel:ch];
    RMQQueue *InviteRoomCallBackQ = [ch queue:@"iceberg.invite_room_callback" options:RMQQueueDeclareDurable];//邀请入群
//    [InviteRoomCallBackQ bind:exchang routingKey:InviteRoomCallBackQ.name];
    [conn start];

    NSDictionary *offlineDic = [[NSDictionary alloc] initWithObjectsAndKeys:issuccess?@"true":@"false",@"success",names,@"user_names",roomUserName,@"room_user_name", nil];
    NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:offlineDic,@"payload",[UserInfo shareUserInfo].userName,@"user_name", nil];
    
    [ch.defaultExchange publish:[self dictionaryToJson:dic] routingKey:InviteRoomCallBackQ.name];
}

//自动回复
- (id)SendTextMessage:(id)arg1 toUsrName:(id)arg2 msgText:(id)arg3 atUserList:(id)arg4;
{
    NSString *currentUserName = [NSString stringWithFormat:@"%@",[objc_getClass("CUtility") GetCurrentUserName]];
    MessageService *msgService = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("MessageService")];
    id obj = [msgService SendTextMessage:currentUserName toUsrName:arg2 msgText:arg3 atUserList:arg4];
    return obj;
}

//自动邀请入群
- (BOOL)InviteGroupMemberWithChatRoomName:(NSString *)arg1 memberList:(NSArray *)arg2 completion:(id(^)(id))arg2block;
{
    GroupStorage *groupStorage = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("GroupStorage")];
     return [groupStorage InviteGroupMemberWithChatRoomName:arg1 memberList:arg2 completion:arg2block];
}

//自动拉入群
- (BOOL)AddGroupMembers:(NSArray *)arg1 withGroupUserName:(NSString *)arg2 completion:(id(^)(id))arg3;
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
- (void)SendImgMessage:(NSDictionary *)info
{
    NSString *toUserName = info[@"user_name"];
    NSString *imgUrl = info[@"image_url"];
    
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
        [self SendImgMessage:currentUserName toUsrName:toUserName thumbImgData:thumbData midImgData:midData imgData:imageData imgInfo:imgInfo];
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
        [self SendImgMessage:currentUserName toUsrName:toUserName thumbImgData:thumbData midImgData:midData imgData:imageData imgInfo:imgInfo];
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
            [self SendImgMessage:currentUserName toUsrName:toUserName thumbImgData:thumbData midImgData:midData imgData:imageData imgInfo:imgInfo];
        }];
    }
}

//发送图片消息
- (id)SendImgMessage:(id)arg1 toUsrName:(id)arg2 thumbImgData:(id)arg3 midImgData:(id)arg4 imgData:(id)arg5 imgInfo:(id)arg6;
{
    MessageService *msgService = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("MessageService")];
    id obj = [msgService SendImgMessage:arg1 toUsrName:arg2 thumbImgData:arg3 midImgData:arg4 imgData:arg5 imgInfo:arg6];
    return obj;
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
        NSLog(@"json解析失败：%@",err);
        return nil;
    }
    return dic;
}

//压缩图片
- (NSData *)compressOriginalImage:(NSImage *)image toMaxDataSizeKBytes:(CGFloat)size
{
    NSData * data = [image TIFFRepresentation];
    CGFloat dataKBytes = data.length/1024.0;
    CGFloat maxQuality = 0.9f;
    CGFloat lastData = dataKBytes;
    while (dataKBytes > size && maxQuality > 0.01f) {
        maxQuality = maxQuality - 0.01f;
        NSNumber *quality = [NSNumber numberWithFloat:maxQuality];
        NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:data];
        NSDictionary *imageProps = [NSDictionary dictionaryWithObject:quality forKey:NSImageCompressionFactor];
        data = [imageRep representationUsingType:NSJPEGFileType properties:imageProps];
        dataKBytes = data.length / 1024.0;
        if (lastData == dataKBytes) {
            break;
        }else{
            lastData = dataKBytes;
        }
    }
    return data;
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
