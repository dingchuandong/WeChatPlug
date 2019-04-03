 //
//  NSObject+hookWechat.m
//  WechatPluginPro
//
//  Created by 刘伟 on 2017/11/29.
//  Copyright © 2017年 boohee. All rights reserved.
//

#import "NSObject+hookWechat.h"
#import "IcelandClient.h"
#import "IcelandConsumer.h"

static WCContactData *contactData;
static IcelandConsumer *consumer;
static IcelandClient *client;


static int loadFinishedCount;  //执行icelandHookClassMethodOnGetOnlineInfoFinished方法的次数（第二次标识好友及群数据已经加载完成）
static bool resolvedLoginType; //是否已经处理 LoginType

@implementation NSObject (hookWechat)

+ (void)startIceland;
{
    [self initLog];
    DDLogInfo(@"------icelandStarting------");
    [self readConfig];
    [self hookWeChat];
}

+ (void)initLog
{
    // 添加DDASLLogger，你的日志语句将被发送到Console.app
    // [DDLog addLogger:[DDASLLogger sharedInstance]];
    DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
    fileLogger.rollingFrequency = 60 * 60 * 24;
    fileLogger.maximumFileSize = 10 * 1024 * 1024;
    fileLogger.logFileManager.logFilesDiskQuota = 100 * 1024 * 1024;
    fileLogger.logFileManager.maximumNumberOfLogFiles = 10;
    [DDLog addLogger:fileLogger];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];//在xCode控制台输出
}

//读取本地的配置
+ (void)readConfig;
{
    NSDictionary *dataDict = [NSDictionary dictionaryWithContentsOfFile:@"/tmp/iceland-wechat.conf"];
    if (dataDict.allKeys.count > 0) {
        [IcelandConfig shareConfig].RabbitMQURL = dataDict[@"RabbitMQURL"];
        [IcelandConfig shareConfig].HttpURL = dataDict[@"HttpURL"];
        [IcelandConfig shareConfig].AppSecret = dataDict[@"AppSecret"];
        [IcelandConfig shareConfig].BotIdentity = dataDict[@"BotIdentity"];
        [IcelandConfig shareConfig].Host = dataDict[@"Host"];
        [IcelandConfig shareConfig].MultipleInstances = dataDict[@"MultipleInstances"];
        [IcelandConfig shareConfig].UserName = dataDict[@"UserName"];
        [IcelandConfig shareConfig].LoginType = [dataDict[@"LoginType"] intValue];
        if ([dataDict[@"Debug"] boolValue]) {
            [IcelandConfig ddSetLogLevel:DDLogLevelDebug];
        }
        DDLogInfo(@"配置参数为:%@", dataDict);
        //删除配置文件
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL res = [fileManager removeItemAtPath:@"/tmp/iceland-wechat.conf" error:nil];
        if (res) {
            DDLogInfo(@"配置文件删除成功");
        } else {
            DDLogInfo(@"配置文件删除失败");
        }
    } else {
        DDLogError(@"没有读取到本地配置文件");
    }
}

+ (void)hookWeChat {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        consumer = [[IcelandConsumer alloc] init];
        client = [[IcelandClient alloc] init];
    });

    //微信多开
    if ([[IcelandConfig shareConfig].MultipleInstances boolValue]) {
        icelandHookClassMethod(objc_getClass("CUtility"), @selector(HasWechatInstance), [self class], @selector(icelandHookClassMethodHasWechatInstance));
    }

    //拦截发送图片
    icelandHookMethod(objc_getClass("MessageService"), @selector(SendImgMessage:toUsrName:thumbImgData:midImgData:imgData:imgInfo:), [self class], @selector(icelandHookSendImgMessage:toUsrName:thumbImgData:midImgData:imgData:imgInfo:));

    //拦截接收到新消息方法  （收到发送服务器）
    icelandHookMethod(objc_getClass("MessageService"), @selector(OnSyncBatchAddMsgs:isFirstSync:), [self class], @selector(icelandHookSyncBatchAddMsgs:isFirstSync:));

    //拦截确认好友方法  （主动调用）
    icelandHookMethod(objc_getClass("MMFriendRequestMgr"), @selector(acceptFriendRequestWithFriendRequestData:completion:), [self class], @selector(icelandHookClassMethodAcceptFriendRequestWithFriendRequestData:completion:));

    //拦截添加好友时创建MMFriendRequestData对象方法 （拦截 发送服务器 看返回值 是否调用确认好友）
    icelandHookMethod(objc_getClass("MMFriendRequestData"), @selector(initWithDictionary:), [self class], @selector(icelandHookClassMethodInitWithDictionary:));

    //拦截获取群成员列表  （拦截 发送服务器  ）
    icelandHookMethod(objc_getClass("GroupStorage"), @selector(GetGroupMemberListWithGroupUserName:), [self class], @selector(icelandHookClassMethodGetGroupMemberListWithGroupUserName:));

    //拦截获取联系人列表
    icelandHookMethod(objc_getClass("ContactStorage"), @selector(GetAllFriendContacts), [self class], @selector(icelandHookClassMethodGetAllFriendContacts));

    //拦截邀请好友入群方法   (主动调用)
    icelandHookMethod(objc_getClass("GroupStorage"), @selector(InviteGroupMemberWithChatRoomName:memberList:completion:), [self class], @selector(icelandHookClassMethodInviteGroupMemberWithChatRoomName:memberList:completion:));

    //拦截拉好友入群方法    （主动调用）
    icelandHookMethod(objc_getClass("GroupStorage"), @selector(AddGroupMembers:withGroupUserName:completion:), [self class], @selector(icelandHookClassMethodAddGroupMembers:withGroupUserName:completion:));

    //拦截修改备注信息      （主动调用）
    icelandHookMethod(objc_getClass("ContactStorage"), @selector(addOpLog_ModifyContact:sync:), [self class], @selector(icelandHookClassMethodAddOpLog_ModifyContact:sync:));

    //拦截获取登录二维码方法   （发送服务器）
    icelandHookMethod(objc_getClass("QRCodeLoginCGI"), @selector(getQRCodeWithCompletion:), [self class], @selector(icelandHookClassMethodGetQRCodeWithCompletion:));

    //拦截群公告方法        （主动调用）
    icelandHookMethod(objc_getClass("MMChatRoomInfoDetailCGI"), @selector(setChatRoomAnnouncementWithUserName:announceContent:withCompletion:), [self class], @selector(icelandHookClassMethodSetChatRoomAnnouncementWithUserName:announceContent:withCompletion:));

    //尝试拦截获取在线信息方法 （用户掉线，1 通知服务器， 2 关闭进程）
    icelandHookMethod(objc_getClass("Reachability"), @selector(startNotifier), [self class], @selector(icelandHookClassMethodStartNotifier));

    //清除登录信息
//    icelandHookMethod(objc_getClass("MMLoginOneClickViewController"), @selector(loadView), [self class], @selector(icelandHookClassMethodLoadView));

    //登录时调用一次 登录完成调用一次
    icelandHookMethod(objc_getClass("AccountService"), @selector(onGetOnlineInfoFinished), [self class], @selector(icelandHookClassMethodOnGetOnlineInfoFinished));

    //踢人
    icelandHookMethod(objc_getClass("GroupStorage"), @selector(DeleteGroupMemberWithGroupUserName:memberUserNameList:completion:), [self class], @selector(icelandHookDeleteGroupMemberWithGroupUserName:memberUserNameList:completion:));

    icelandHookMethod(objc_getClass("MMSessionMgr"), @selector(GetAllSessions), [self class], @selector(icelandHookGetAllSessions));

    //下载语音
    icelandHookMethod(objc_getClass("MessageService"), @selector(onVoiceDowloadFinished:isSuccess:isNeedSave:offset:), [self class], @selector(icelandHookVoiceDowloadFinished:isSuccess:isNeedSave:offset:));

    //下载图片
    icelandHookMethod(objc_getClass("MMMessageCacheMgr"), @selector(downloadImageFinishedWithMessage:type:isSuccess:), [self class], @selector(icelandHookdownloadImageFinishedWithMessage:type:isSuccess:));
    
    //自动登录
    icelandHookMethod(objc_getClass("MMLoginOneClickViewController"), @selector(viewWillAppear), [self class], @selector(icelandHookviewWillAppear));
    
    //免认证登录
    icelandHookMethod(objc_getClass("MMLoginOneClickViewController"), @selector(onLoginButtonClicked:), [self class], @selector(icelandHookonLoginButtonClicked:));
    icelandHookMethod(objc_getClass("LogoutCGI"), @selector(sendLogoutCGIWithCompletion:), [self class], @selector(icelandHooksendLogoutCGIWithCompletion:));
    icelandHookMethod(objc_getClass("AccountService"), @selector(ManualLogout), [self class], @selector(icelandHookManualLogout));
    
    //群成员
    icelandHookMethod(objc_getClass("GroupStorage"), @selector(GetGroupContactList:ContactType:), [self class], @selector(icelandHookGetGroupContactList:ContactType:));
}

- (NSArray *)icelandHookGetGroupContactList:(unsigned int)arg1 ContactType:(unsigned int)arg2;
{
    NSArray *groupListary = [self icelandHookGetGroupContactList:arg1 ContactType:arg2];
    DDLogDebug(@"获取最新的通讯录群列表 == %@",groupListary);
    //更新数据
    [client getGroupContactList:groupListary];
    return groupListary;
}

- (void)icelandHookdownloadImageFinishedWithMessage:(id)MessageData type:(int)type isSuccess:(BOOL)isSuccess;
{
    if (isSuccess) {
        [client uploadImage:MessageData];
    }
    [self icelandHookdownloadImageFinishedWithMessage:MessageData type:type isSuccess:isSuccess];
}

- (void)icelandHookVoiceDowloadFinished:(id)arg1 isSuccess:(BOOL)arg2 isNeedSave:(BOOL)arg3 offset:(unsigned long long)arg4;
{
    if (arg1) {
        [client uploadVoice:arg1 andBeforeLength:arg4];
    }
    [self icelandHookVoiceDowloadFinished:arg1 isSuccess:arg2 isNeedSave:arg3 offset:arg4];
}

- (id)icelandHookGetAllSessions;
{
    NSArray *ary = [self icelandHookGetAllSessions];
    NSMutableArray *newAry = [[NSMutableArray alloc] init];
    for (MMSessionInfo *info in ary) {
        if ([info.m_nsUserName hasSuffix:@"@chatroom"]) {
            WCContactData *data = info.m_packedInfo.m_contact;
            [newAry addObject:data];
        }
    }
    [client getGroupContactList:newAry];
    return ary;
}

- (void)icelandHookClassMethodOnGetOnlineInfoFinished {

    //count == 2表示已经获取好各类数据
    loadFinishedCount++;
    if (loadFinishedCount == 2) {
        [client uploadUserInfo];
        [consumer initQueue];
    }
    [self icelandHookClassMethodOnGetOnlineInfoFinished];
}


- (void)icelandHookClassMethodLoadView {

    AccountService *accountService = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("AccountService")];
    [accountService ClearLastLoginAutoAuthKey];
    [self icelandHookClassMethodLoadView];
}


/*
 清除数据
 */
- (void)icelandHookClearData
{
    [self icelandHookClearData];
}


/*
 拦截登录状态改变（第一次出发时为登录时，第二次为退出登录时）
 */
- (BOOL)icelandHookClassMethodStartNotifier {

    BOOL result = [self icelandHookClassMethodStartNotifier];
    [client userStatusChanged];
    return result;
}


/*
 拦截修改群公告方法
 */
- (void)icelandHookClassMethodSetChatRoomAnnouncementWithUserName:(id)arg1 announceContent:(id)arg2 withCompletion:(id)arg3 {

    [self icelandHookClassMethodSetChatRoomAnnouncementWithUserName:arg1 announceContent:arg2 withCompletion:arg3];
}


- (void)icelandHookviewWillAppear {
    [self icelandHookviewWillAppear];
    
    if (![self.className isEqualToString:@"MMLoginOneClickViewController"]) return;
    
    // 确保自动登录处理只执行一次
    if (resolvedLoginType) return;
    resolvedLoginType = true;
    
    WeChat *wechat = [objc_getClass("WeChat") sharedInstance];
    MMLoginOneClickViewController *loginVC = wechat.mainWindowController.loginViewController.oneClickViewController;
    //如果本地配置与当前用户不符合 清除本地配置 重新上传二维码给服务器
    AccountService *accountService = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("AccountService")];
    NSString *lastUserName = [accountService GetLastLoginUserName];
    NSString *configUserName = [IcelandConfig shareConfig].UserName;
    
    if ([lastUserName isEqualToString:configUserName]) {
        if ([IcelandConfig shareConfig].LoginType == ScanCode) {
            [objc_getClass("CUtility") KernelRemoveUserPrivacyFilesWithUserName:lastUserName];
            [accountService ClearLastLoginAutoAuthKey];
            DDLogInfo(@"上次登录用户为：%@\n 配置文件登录用户为：%@\n 配置文件要求扫码登录优先", lastUserName, configUserName);
        }else if ([IcelandConfig shareConfig].LoginType == ConfirmLogin){
            [objc_getClass("CUtility") KernelRemoveUserPrivacyFilesWithUserName:lastUserName];
            DDLogInfo(@"上次登录用户为：%@\n 配置文件登录用户为：%@\n 配置文件要求确认登录优先", lastUserName, configUserName);
        }
    }else{
        [objc_getClass("CUtility") KernelRemoveUserPrivacyFilesWithUserName:lastUserName];
        [accountService ClearLastLoginAutoAuthKey];
        DDLogInfo(@"上次登录用户为：%@\n 配置文件登录用户为：%@\n 本地配置与上次登录用户不一致 清除本地配置", lastUserName, configUserName);
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [loginVC onLoginButtonClicked:nil];
    });
}

/*
 免认证登录
*/
- (void)icelandHookonLoginButtonClicked:(NSButton *)btn {
    AccountService *accountService = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("AccountService")];
    //2 表示自动登录优先
    if ([IcelandConfig shareConfig].LoginType == AutoAuth && [accountService canAutoAuth]) {
        [accountService AutoAuth];
        DDLogInfo(@"免认证登陆成功");
    } else {
        [self icelandHookonLoginButtonClicked:btn];
        DDLogInfo(@"主动调用登录按钮事件");
    }
}

/*
 退出登录方法(主动调用 mac)
 */
- (void)icelandHooksendLogoutCGIWithCompletion:(id)arg1 {
    //为下次免密登录做准备
    BOOL autoAuthEnable = YES;
    WeChat *wechat = [objc_getClass("WeChat") sharedInstance];
    if (autoAuthEnable && wechat.isAppTerminating){
        //通知服务器退出登录了
        [client userStatusChanged];
        return;
    }
    [self icelandHooksendLogoutCGIWithCompletion:arg1];
    //通知服务器退出登录了
    [client userStatusChanged];
}

- (void)icelandHookManualLogout {
    //为下次免密登录做准备
    BOOL autoAuthEnable = YES;
    if (autoAuthEnable)
    return;
    [self icelandHookManualLogout];
}

/*
 拦截获取登录二维码方法
 */
- (void)icelandHookClassMethodGetQRCodeWithCompletion:(QRBlock)arg1 {

    [self icelandHookClassMethodGetQRCodeWithCompletion:^(id argarg1) {
        [client getQRCodeWithCompletion:argarg1];
        arg1(argarg1);
    }];
}

/*
 拦截修改备注方法
 */
- (BOOL)icelandHookClassMethodAddOpLog_ModifyContact:(id)arg1 sync:(BOOL)arg2 {

    BOOL result = [self icelandHookClassMethodAddOpLog_ModifyContact:arg1 sync:arg2];
    return result;
}


/**
 拦截拉好友入群方法
 */
- (BOOL)icelandHookClassMethodAddGroupMembers:(NSArray *)arg1 withGroupUserName:(NSString *)arg2 completion:(id(^)(id))arg3 {

    BOOL result = [self icelandHookClassMethodAddGroupMembers:arg1 withGroupUserName:arg2 completion:arg3];
    return result;
}

/**
 拦截发送入群邀请方法
 */
- (BOOL)icelandHookClassMethodInviteGroupMemberWithChatRoomName:(NSString *)arg1 memberList:(NSArray *)arg2 completion:(id(^)(id))arg2block {

    BOOL result = [self icelandHookClassMethodInviteGroupMemberWithChatRoomName:arg1 memberList:arg2 completion:arg2block];
    return result;
}

/**
 拦截获取联系人列表方法
 */
- (NSArray *)icelandHookClassMethodGetAllFriendContacts {

    NSArray *result = [self icelandHookClassMethodGetAllFriendContacts];
    contactData = result[0];

    //全局变量替换 服务器上传增量上传
    if (result.count > 0) {
        [client getAllFriendContacts:result];
    }
    return result;
}


/**
 拦截获取群成员列表方法
 */
- (NSArray *)icelandHookClassMethodGetGroupMemberListWithGroupUserName:(id)arg1 {

    NSArray *result = [self icelandHookClassMethodGetGroupMemberListWithGroupUserName:arg1];
    if (result.count > 0) {
        //        [consumer GetGroupMemberListWithGroupUserName:result andGroupID:arg1];
    }
    return result;
}

/**
 拦截添加好友时创建MMFriendRequestData对象方法
 延时5秒自动通过好友验证
 */
- (id)icelandHookClassMethodInitWithDictionary:(id)arg1 {

    id friendRequestData = [self icelandHookClassMethodInitWithDictionary:arg1];
    [client setFriendRequestData:friendRequestData];
    return friendRequestData;
}

/**
 拦截确认好友方法
 */
- (id)icelandHookClassMethodAcceptFriendRequestWithFriendRequestData:(MMFriendRequestData *)arg1 completion:(id(^)(id))arg2block{

    id acceptFriendRequest = nil;
    acceptFriendRequest = [self icelandHookClassMethodAcceptFriendRequestWithFriendRequestData:arg1 completion:arg2block];
    [client acceptFriendRequestWithFriendRequestData:arg1 completion:arg2block];
    return acceptFriendRequest;
}

/**
 消息同步方法
 */
- (void)icelandHookSyncBatchAddMsgs:(NSArray *)msgs isFirstSync:(BOOL)arg2{

//测试专用
//    AddMsg *addmsg = (AddMsg *)msgs[0];
//
//    NSString *content = addmsg.content.string;
//    NSString *fromUserName = addmsg.fromUserName.string;
//    NSString *toUserName = addmsg.toUserName.string;
//    int type = addmsg.msgType;
//
//    //打印消息对象
//    DDLogDebug(@"--------消息详细信息---------");
//    DDLogDebug(@"发消息人：%@  \n   收消息人：%@   \n   消息内容：%@  \n 消息类型：%d  \n", fromUserName, toUserName, content, type);
//
//    //自动回复
//    client *helper = [[client alloc] init];
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
//    //修改日志等级
//    if ([content isEqualToString:@"debug"]) {
//        [IcelandConfig ddSetLogLevel:DDLogLevelDebug];
//    }
//    if ([content isEqualToString:@"info"]) {
//        [IcelandConfig ddSetLogLevel:DDLogLevelInfo];
//    }
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
    //是否同步
    [client batchAddMsgs:msgs isFirstSync:arg2];
    [self icelandHookSyncBatchAddMsgs:msgs isFirstSync:arg2];
}


/**
 微信多开 No（允许多开）
 */
+ (BOOL)icelandHookClassMethodHasWechatInstance {
    return NO;
}

/**
 发送图片消息
 */
- (id)icelandHookSendImgMessage:(id)arg1 toUsrName:(id)arg2 thumbImgData:(id)arg3 midImgData:(id)arg4 imgData:(id)arg5 imgInfo:(id)arg6;
{
    id res = [self icelandHookSendImgMessage:arg1 toUsrName:arg2 thumbImgData:arg3 midImgData:arg4 imgData:arg5 imgInfo:arg6];
    return res;
}

/**
 踢人
 **/
- (BOOL)icelandHookDeleteGroupMemberWithGroupUserName:(id)arg1 memberUserNameList:(id)arg2 completion:(id)arg3
{
    return [self icelandHookDeleteGroupMemberWithGroupUserName:arg1 memberUserNameList:arg2 completion:arg3];
}


@end

