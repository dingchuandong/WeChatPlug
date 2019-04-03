 //
//  NSObject+hookWechat.m
//  WechatPluginPro
//
//  Created by 刘伟 on 2017/11/29.
//  Copyright © 2017年 刘伟. All rights reserved.
//

#import "NSObject+hookWechat.h"
#import "ServerCallHelper.h"
#import "CallServerHelper.h"
#import "UserInfo.h"
#import "WriteLogHandler.h"

static WCContactData *contactData;
static CallServerHelper *callServerHelper;
static ServerCallHelper *serverCallHelper;


static int loadFinishedCount;//执行skingOnGetOnlineInfoFinished方法的次数（第二次标识好友及群数据已经加载完成）

@implementation NSObject (hookWechat)

//读取本地的配置
+ (void)readConfig;
{
    NSDictionary *dataDict = [NSDictionary dictionaryWithContentsOfFile:@"/tmp/iceland-wechat.conf"];
    if (dataDict.allKeys.count > 0) {
        NSLog(@"%@\n%@\n%@",[UserInfo shareUserInfo].RabbitMQURL,[UserInfo shareUserInfo].HttpURL,[UserInfo shareUserInfo].AppSecret);
        [UserInfo shareUserInfo].RabbitMQURL = dataDict[@"RabbitMQURL"];
        [UserInfo shareUserInfo].HttpURL = dataDict[@"HttpURL"];
        [UserInfo shareUserInfo].AppSecret = dataDict[@"AppSecret"];
         NSLog(@"%@\n%@\n%@",[UserInfo shareUserInfo].RabbitMQURL,[UserInfo shareUserInfo].HttpURL,[UserInfo shareUserInfo].AppSecret);
        [[WriteLogHandler shareLogHander] writefile:[NSString stringWithFormat:@"配置参数为:\n%@\n%@\n%@",[UserInfo shareUserInfo].RabbitMQURL,[UserInfo shareUserInfo].HttpURL,[UserInfo shareUserInfo].AppSecret]];

        //删除配置文件
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL res = [fileManager removeItemAtPath:@"/tmp/iceland-wechat.conf" error:nil];
        if (res) {
            [[WriteLogHandler shareLogHander] writefile:@"配置文件删除成功"];
        }else
            [[WriteLogHandler shareLogHander] writefile:@"配置文件删除失败"];
    }else{
        [[WriteLogHandler shareLogHander] writefile:@"没有读取到本地配置文件"];
    }
    
    [self hookWeChat];
}

+ (void)hookWeChat {
        
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        callServerHelper = [[CallServerHelper alloc] init];
        serverCallHelper = [[ServerCallHelper alloc] init];
    });
    
    //微信多开
    sking_hookClassMethod(objc_getClass("CUtility"), @selector(HasWechatInstance), [self class], @selector(skingHasWechatInstance));
    
    //拦截微信发送消息方法  （发送服务器）
    sking_hookMethod(objc_getClass("MessageService"), @selector(SendTextMessage:toUsrName:msgText:atUserList:), [self class], @selector(hook_onSendTextMessage: toUsrName:msgText:atUserList:));
    
    //拦截发送图片
    sking_hookMethod(objc_getClass("MessageService"), @selector(SendImgMessage:toUsrName:thumbImgData:midImgData:imgData:imgInfo:), [self class], @selector(hook_SendImgMessage:toUsrName:thumbImgData:midImgData:imgData:imgInfo:));
    
    //拦截微信撤回消息方法(不用 暂时)
//    sking_hookMethod(objc_getClass("MessageService"), @selector(onRevokeMsg:), [self class], @selector(hook_onRevokeMsg:));
    
    //拦截接收到新消息方法  （收到发送服务器）
    sking_hookMethod(objc_getClass("MessageService"), @selector(OnSyncBatchAddMsgs:isFirstSync:), [self class], @selector(hook_OnSyncBatchAddMsgs:isFirstSync:));
    
    //拦截确认好友方法  （主动调用）
    sking_hookMethod(objc_getClass("MMFriendRequestMgr"), @selector(acceptFriendRequestWithFriendRequestData:completion:), [self class], @selector(skingAcceptFriendRequestWithFriendRequestData:completion:));
    
    //拦截添加好友时创建MMFriendRequestData对象方法 （拦截 发送服务器 看返回值 是否调用确认好友）
    sking_hookMethod(objc_getClass("MMFriendRequestData"), @selector(initWithDictionary:), [self class], @selector(skingInitWithDictionary:));
    
    //拦截获取群成员列表  （拦截 发送服务器  ）
    sking_hookMethod(objc_getClass("GroupStorage"), @selector(GetGroupMemberListWithGroupUserName:), [self class], @selector(skingGetGroupMemberListWithGroupUserName:));
    
    //拦截获取群列表方法
    sking_hookMethod(objc_getClass("GroupStorage"), @selector(GetGroupContactList:ContactType:), [self class], @selector(skingGetGroupContactList:ContactType:));
    
    //拦截获取联系人列表
    sking_hookMethod(objc_getClass("ContactStorage"), @selector(GetAllFriendContacts), [self class], @selector(skingGetAllFriendContacts));
    
    //拦截邀请好友入群方法   (主动调用)
    sking_hookMethod(objc_getClass("GroupStorage"), @selector(InviteGroupMemberWithChatRoomName:memberList:completion:), [self class], @selector(skingInviteGroupMemberWithChatRoomName:memberList:completion:));
    
    //拦截拉好友入群方法    （主动调用）
    sking_hookMethod(objc_getClass("GroupStorage"), @selector(AddGroupMembers:withGroupUserName:completion:), [self class], @selector(skingAddGroupMembers:withGroupUserName:completion:));
    
    //拦截修改备注信息      （主动调用）
    sking_hookMethod(objc_getClass("ContactStorage"), @selector(addOpLog_ModifyContact:sync:), [self class], @selector(skingAddOpLog_ModifyContact:sync:));
    
    //拦截获取登录二维码方法   （发送服务器）
    sking_hookMethod(objc_getClass("QRCodeLoginCGI"), @selector(getQRCodeWithCompletion:), [self class], @selector(skingGetQRCodeWithCompletion:));
    
    //拦截群公告方法        （主动调用）
    sking_hookMethod(objc_getClass("MMChatRoomInfoDetailCGI"), @selector(setChatRoomAnnouncementWithUserName:announceContent:withCompletion:), [self class], @selector(skingSetChatRoomAnnouncementWithUserName:announceContent:withCompletion:));
    
    //尝试拦截获取在线信息方法 （用户掉线，1 通知服务器， 2 关闭进程）
    sking_hookMethod(objc_getClass("Reachability"), @selector(startNotifier), [self class], @selector(skingStartNotifier));
    
    //退出登录(没有拦截到)
    sking_hookMethod(objc_getClass("LogoutCGI"), @selector(sendLogoutCGIWithCompletion:), [self class], @selector(skingSendLogoutCGIWithCompletion:));
    
    //清除登录信息
    sking_hookMethod(objc_getClass("MMLoginOneClickViewController"), @selector(loadView), [self class], @selector(skingLoadView));
    
    //登录时调用一次 登录完成调用一次
    sking_hookMethod(objc_getClass("AccountService"), @selector(onGetOnlineInfoFinished), [self class], @selector(skingOnGetOnlineInfoFinished));

    //获取小图方法
    sking_hookMethod(objc_getClass("NSImage"), @selector(thumbnailDataForMessage), [self class], @selector(skingThumbnailDataForMessage));
    
    //获取中图方法
    sking_hookMethod(objc_getClass("NSImage"), @selector(middleImageDataWithCompletion:), [self class], @selector(skingMiddleImageDataWithCompletion:));
    
}


- (void)skingOnGetOnlineInfoFinished {
    
    //count == 2表示已经获取好各类数据
    loadFinishedCount++;
    if (loadFinishedCount == 2) {
        [callServerHelper setisFinishedLoad:YES];
        [serverCallHelper initQueue];
    }
    [self skingOnGetOnlineInfoFinished];
}


- (void)skingLoadView {
    
    AccountService *accountService = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("AccountService")];
    [accountService ClearLastLoginAutoAuthKey];
    [self skingLoadView];
}

/*
 退出登录方法(主动调用 mac)
 */
- (void)skingSendLogoutCGIWithCompletion:(id)arg1 {
    
    [self skingSendLogoutCGIWithCompletion:arg1];
    //通知服务器退出登录了
    [callServerHelper StartNotifier:YES];
}


/*
 清除数据
 */
- (void)hook_ClearData
{
    [self hook_ClearData];
}

/*
 拦截登录状态改变（第一次出发时为登录时，第二次为退出登录时）
 */
- (BOOL)skingStartNotifier {
    
    BOOL result = [self skingStartNotifier];
    
    [callServerHelper StartNotifier:result];
    
    return result;
}


/*
 拦截修改群公告方法
 */
- (void)skingSetChatRoomAnnouncementWithUserName:(id)arg1 announceContent:(id)arg2 withCompletion:(id)arg3 {
    
    [self skingSetChatRoomAnnouncementWithUserName:arg1 announceContent:arg2 withCompletion:arg3];
}

/*
 拦截获取登录二维码方法
 */
- (void)skingGetQRCodeWithCompletion:(QRBlock)arg1 {
    
    [self skingGetQRCodeWithCompletion:^(id argarg1) {
        [callServerHelper GetQRCodeWithCompletion:argarg1];
        arg1(argarg1);
    }];
}


/*
 拦截修改备注方法
 */
- (BOOL)skingAddOpLog_ModifyContact:(id)arg1 sync:(BOOL)arg2 {
    
    BOOL result = [self skingAddOpLog_ModifyContact:arg1 sync:arg2];
    return result;
}


/**
 拦截拉好友入群方法
 */
- (BOOL)skingAddGroupMembers:(NSArray *)arg1 withGroupUserName:(NSString *)arg2 completion:(id(^)(id))arg3 {
    
    BOOL result = [self skingAddGroupMembers:arg1 withGroupUserName:arg2 completion:arg3];
    return result;
}

/**
 拦截发送入群邀请方法
 */
- (BOOL)skingInviteGroupMemberWithChatRoomName:(NSString *)arg1 memberList:(NSArray *)arg2 completion:(id(^)(id))arg2block {
    
    BOOL result = [self skingInviteGroupMemberWithChatRoomName:arg1 memberList:arg2 completion:arg2block];
    return result;
}


/**
 拦截群列表方法
 */
- (NSArray *)skingGetGroupContactList:(unsigned int)arg1 ContactType:(unsigned int)arg2 {
    
    NSArray *result = [self skingGetGroupContactList:arg1 ContactType:arg2];
    if (result.count > 0) {
        [callServerHelper GetGroupContactList:result];
    }
    return result;
}

/**
 拦截获取联系人列表方法
 */
- (NSArray *)skingGetAllFriendContacts {
    
    NSArray *result = [self skingGetAllFriendContacts];
    contactData = result[0];
    
    //全局变量替换 服务器上传增量上传
    if (result.count > 0) {
        [callServerHelper GetAllFriendContacts:result];
    }
    return result;
}


/**
 拦截获取群成员列表方法
 */
- (NSArray *)skingGetGroupMemberListWithGroupUserName:(id)arg1 {
    
    NSArray *result = [self skingGetGroupMemberListWithGroupUserName:arg1];
    if (result.count > 0) {
        //        [callServerHelper GetGroupMemberListWithGroupUserName:result andGroupID:arg1];
    }
    return result;
}

/**
 拦截添加好友时创建MMFriendRequestData对象方法
 延时5秒自动通过好友验证
 */
- (id)skingInitWithDictionary:(id)arg1 {
    
    id test = [self skingInitWithDictionary:arg1];
    [callServerHelper InitWithDictionary:test];
    return test;
}

/**
 拦截确认好友方法
 */
- (id)skingAcceptFriendRequestWithFriendRequestData:(MMFriendRequestData *)arg1 completion:(id(^)(id))arg2block{
    
    id test = nil;
    test = [self skingAcceptFriendRequestWithFriendRequestData:arg1 completion:arg2block];
    [callServerHelper AcceptFriendRequestWithFriendRequestData:arg1 completion:arg2block];
    return test;
}

/**
 消息同步方法
 */
- (void)hook_OnSyncBatchAddMsgs:(NSArray *)msgs isFirstSync:(BOOL)arg2{
    
    //测试专用
//    AddMsg *addmsg = (AddMsg *)msgs[0];
//
//    NSString *content = addmsg.content.string;
//    NSString *fromUserName = addmsg.fromUserName.string;
//    NSString *toUserName = addmsg.toUserName.string;
//    int type = addmsg.msgType;
//
//    //打印消息对象
//    NSLog(@"--------消息详细信息---------");
//    NSLog(@"发消息人：%@  \n   收消息人：%@   \n   消息内容：%@  \n 消息类型：%d  \n", fromUserName, toUserName, content, type);
//
//    //自动回复
//    ServerCallHelper *helper = [[ServerCallHelper alloc] init];
//
//    [helper SendImgMessage:nil];
//    if ([content isEqualToString:@"回复"]) {
//
//        float interval  = 0;
//        interval = arc4random()%5 + 5;
//        [helper SendTextMessage:nil toUsrName:@"5622345566@chatroom" msgText:@"@飞逝 你好" atUserList:@"dcd_314"];
//
//        NSArray *ary = [[NSArray alloc] init];
//        id test = ary[1];
//    }
//
//    if ([content isEqualToString:@"好友"]) {
//        NSString *currentUserName = [objc_getClass("CUtility") GetCurrentUserName];
//        MessageService *msgService = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("MessageService")];
//        float interval  = 0;
//        interval = arc4random()%5 + 5;
//        [helper SendTextMessage:currentUserName toUsrName:fromUserName msgText:@"么么哒" atUserList:nil];
//    }
//
//    //自动邀请入群
//    if ([content isEqualToString:@"邀请入群"]) {
//        GroupMember *newmember = [[objc_getClass("GroupMember") alloc] init];
//
//        newmember.m_uiMemberStatus = 0;
//        newmember.m_nsMemberName = fromUserName;
//        newmember.m_nsNickName = nil;
//
//        NSArray *memberList = @[newmember];
//
//        id completion;
//
//        [helper InviteGroupMemberWithChatRoomName:@"5622345566@chatroom" memberList:memberList completion:completion];
//    }
//
//    //自动拉入群
//    if ([content isEqualToString:@"自动入群"]) {
//        GroupMember *newmember = [[objc_getClass("GroupMember") alloc] init];
//
//        newmember.m_uiMemberStatus = 0;
//        newmember.m_nsMemberName = fromUserName;
//        newmember.m_nsNickName = nil;
//
//        NSArray *memberList = @[newmember];
//
//        id completion;
//        [helper AddGroupMembers:memberList withGroupUserName:@"5622345566@chatroom" completion:completion];
//    }
//
//    //修改好友备注
//    if ([content isEqualToString:@"修改备注"]) {
//        contactData.m_nsRemark = @"啦破达~~^^^^";
//        [helper addOpLog_ModifyContact:contactData sync:0];
//    }
//
//    //修改群公告
//    if ([content isEqualToString:@"修改群公告"]) {
//        [helper setChatRoomAnnouncementWithUserName:@"5622345566@chatroom" announceContent:@"修改一波~~~~" withCompletion:nil];
//    }
//
//    //收到 图片
//    if (type == 3 || [content isEqualToString:@"图片"]) {
//        //        for (  *chats in ) {
//        //
//        //        }
//        if ([NSThread isMainThread])
//        {
//            WeChat *wechat = [objc_getClass("WeChat") sharedInstance];
//            [wechat.chatsViewController selectChatWithUserName:fromUserName];
//        }else{
//            dispatch_sync(dispatch_get_main_queue(), ^{
//                //Update UI in UI thread here
//                WeChat *wechat = [objc_getClass("WeChat") sharedInstance];
//                [wechat.chatsViewController selectChatWithUserName:fromUserName];
//            });
//        }
//    }
    
    [callServerHelper BatchAddMsgs:msgs isFirstSync:arg2];
    [self hook_OnSyncBatchAddMsgs:msgs isFirstSync:arg2];
}


/**
 微信多开
 */
+ (BOOL)skingHasWechatInstance {
    return NO;
}

/**
 发送消息
 */
- (id)hook_onSendTextMessage:(id)arg1 toUsrName:(id)arg2 msgText:(id)arg3 atUserList:(id)arg4;
{
    
    //通知服务器
    if (arg3) {
        [callServerHelper SendTextMessage:arg1 toUsrName:arg2 msgText:arg3 atUserList:arg4];
        id res = [self hook_onSendTextMessage:arg1 toUsrName:arg2 msgText:arg3 atUserList:arg4];
        return res;
    }else {
        return nil;
    }
    
}

/**
 发送图片消息
 */
- (id)hook_SendImgMessage:(id)arg1 toUsrName:(id)arg2 thumbImgData:(id)arg3 midImgData:(id)arg4 imgData:(id)arg5 imgInfo:(id)arg6;
{
    id res = [self hook_SendImgMessage:arg1 toUsrName:arg2 thumbImgData:arg3 midImgData:arg4 imgData:arg5 imgInfo:arg6];
    return res;
}

- (void)skingMiddleImageDataWithCompletion:(MidRBlock)arg1 {
    
    [self skingMiddleImageDataWithCompletion:^(id argarg1) {
        NSData * middata = argarg1;
        NSLog(@"middleImg class == %@ lengthis == %ld", [argarg1 class], middata.length);
        arg1(argarg1);
    }];
}

- (id)skingThumbnailDataForMessage {
    
    MessageThumbData *result = [self skingThumbnailDataForMessage];
    NSLog(@"thumbimg == %@ length == %ld", result, result.data.length);
    
    return result;
}

@end

