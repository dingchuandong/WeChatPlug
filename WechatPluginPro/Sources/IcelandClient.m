//
//  CallServerHelper.m
//  WechatPluginPro
//
//  Created by dcd on 2017/12/14.
//  Copyright © 2017年 boohee. All rights reserved.
//

#import "IcelandClient.h"
#import <AppKit/AppKit.h>
#import <AFNetworking.h>
#import <CommonCrypto/CommonCrypto.h>
#import "XMLReader.h"
#import "CommonHelper.h"
#import "NSData+DCDCompress.h"

@interface IcelandClient ()
@end

@implementation IcelandClient

-(instancetype)init
{
    if (self=[super init]) {

        //初始化链接
        RMQTLSOptions *tlsOptions = [RMQTLSOptions fromURI:[IcelandConfig shareConfig].RabbitMQURL verifyPeer:NO];
        RMQConnection *conn = [[RMQConnection alloc] initWithUri:[IcelandConfig shareConfig].RabbitMQURL tlsOptions:tlsOptions channelMax:@65535 frameMax:@131072 heartbeat:@0 syncTimeout:@30 delegate:[RMQConnectionDelegateLogger new] delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) recoverAfter:@4 recoveryAttempts:@(NSUIntegerMax) recoverFromConnectionClose:YES];
        _clientChannel = [conn createChannel];

        _qRCodeQ = [_clientChannel queue:@"iceberg.qrcode_json" options:RMQQueueDeclareDurable];
        _allFriendQ = [_clientChannel queue:@"iceberg.contacts" options:RMQQueueDeclareDurable];
        _incrementalFriendQ = [_clientChannel queue:@"iceberg.new_contacts" options:RMQQueueDeclareDurable];
        _groupContactListQ = [_clientChannel queue:@"iceberg.rooms" options:RMQQueueDeclareDurable];
        _groupMemberListQ = [_clientChannel queue:@"iceberg.room_members" options:RMQQueueDeclareDurable];
        _whispersMessagesQ = [_clientChannel queue:@"iceberg.whispers" options:RMQQueueDeclareDurable];
        _messagesQ = [_clientChannel queue:@"iceberg.messages" options:RMQQueueDeclareDurable];
        _offLineQ = [_clientChannel queue:@"iceberg.offline" options:RMQQueueDeclareDurable];
        _acceptFriendCallBackQ = [_clientChannel queue:@"iceberg.accept_friend_callback" options:RMQQueueDeclareDurable];
        _serverHeartbeatQ = [_clientChannel queue:@"iceberg.heartbeat" options:RMQQueueDeclareDurable];

        // 初始化连接
        [conn start];

        [self initTiming];
    }
    return self;
}

- (void)createServerHeartbeatQ
{
    //不适用NSTimer 误差太大
    if(_heartbeatTimer == nil)
    {
        // 创建队列
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        _heartbeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    }

    dispatch_source_set_timer(_heartbeatTimer, DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(_heartbeatTimer, ^{
        NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:[NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970]],@"timestamp", nil];

        NSString *currentUserName = [objc_getClass("CUtility") GetCurrentUserName];
        if (currentUserName) {
            NSDictionary *infoDic = [[NSDictionary alloc] initWithObjectsAndKeys:currentUserName,@"user_name",dic,@"payload", nil];
            [_clientChannel.defaultExchange publish:[self dictionaryToData:infoDic] routingKey:_serverHeartbeatQ.name];
            DDLogInfo(@"发送心跳：%@", currentUserName);
        }else{
            DDLogInfo(@"进程被终止了（心跳） 方法名：%s",__func__);
            [CommonHelper KillApp];
        }
    });
    dispatch_resume(_heartbeatTimer);
}

//获取登录的二维码
- (void)getQRCodeWithCompletion:(NSImage *)arg1;
{
    if (_isActiveQuit) {
        return;
    }
    NSData *imageData = [arg1 TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
    [imageRep setSize:CGSizeMake(2000, 2000)];
    //图片质量
    NSNumber *quality = [NSNumber numberWithFloat:1];
    NSDictionary *imageProps = [NSDictionary dictionaryWithObject:quality forKey:NSImageCompressionFactor];
    NSData * imageData1 = [imageRep representationUsingType:NSPNGFileType properties:imageProps];

    NSMutableDictionary *msgDic = [[NSMutableDictionary alloc] init];

    NSString *imgStr = [imageData1 base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];;
    [msgDic setValue:imgStr forKey:@"qrcode"];
    [msgDic setValue:[IcelandConfig shareConfig].BotIdentity forKey:@"bot_identity"];
    [msgDic setValue:[IcelandConfig shareConfig].Host forKey:@"iceland_host"];
    [_clientChannel.defaultExchange publish:[self dictionaryToData:msgDic] routingKey:_qRCodeQ.name];
    DDLogInfo(@"上传服务器登录二维码：BotIdentity == %@  Host == %@", [IcelandConfig shareConfig].BotIdentity,[IcelandConfig shareConfig].Host);
}

//接收到新消息
- (void)batchAddMsgs:(NSArray *)msgs isFirstSync:(BOOL)arg2;
{
    for (AddMsg *addmsg in msgs) {
        [self uploadMessage:addmsg];
    }
}

- (void)uploadMessage:(AddMsg *)addmsg
{
    NSString *content = addmsg.content.string;
    NSString *fromUserName = addmsg.fromUserName.string;
    int type = addmsg.msgType;

    //添加文字（1），表情（47），图片（3），小程序 文件 聊天记录 红包 转账 卡片形式链接（49），语音（34），视频（43），名片（42），位置信息（48）
    if (type == 1 || type == 10000 || type == 3 || type == 47 || type == 49 || type == 34 || type == 43 || type == 42 || type == 48) {
        NSMutableDictionary *msgDic = [[NSMutableDictionary alloc] init];
        [msgDic setValue:content forKey:@"content"];
        [msgDic setValue:fromUserName forKey:@"from_user_name"];
        [msgDic setValue:addmsg.toUserName.string forKey:@"to_user_name"];
        [msgDic setValue:[NSString stringWithFormat:@"%d",addmsg.msgType] forKey:@"message_type"];
        [msgDic setValue:[NSString stringWithFormat:@"%d",addmsg.msgId] forKey:@"message_id"];
        [msgDic setValue:[NSString stringWithFormat:@"%lld",addmsg.newMsgId] forKey:@"new_message_id"];
        [msgDic setValue:[NSString stringWithFormat:@"%d",addmsg.createTime] forKey:@"create_time"];

        NSString *currentUserName = [objc_getClass("CUtility") GetCurrentUserName];

        NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:msgDic,@"payload",currentUserName,@"user_name", nil];

        if ([fromUserName containsString:@"@chatroom"]) {
            //群消息
            NSArray *strAry = [content componentsSeparatedByString:@":\n"];
            if (strAry.count > 1) {
                [msgDic setValue:strAry[0] forKey:@"sender_user_name"];
                [msgDic setValue:[content stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@:\n",strAry[0]] withString:@""] forKey:@"content"];
            }
            //取@列表
            NSArray *strAry1 = [addmsg.msgSource componentsSeparatedByString:@"![CDATA["];
            if (strAry1.count > 1) {
                strAry1 = [strAry1[1] componentsSeparatedByString:@"]]"];
                if (strAry1.count > 0) {
                    strAry1 = [strAry1[0] componentsSeparatedByString:@","];
                    [msgDic setValue:strAry1 forKey:@"at_user_list"];
                }
            }
            //图片消息 content 传空
            if (type == 3 || type == 34) {
                [msgDic setValue:@"" forKey:@"content"];
            }
            //表示群成员发生了改变
            if (type == 10000 && [content rangeOfString:@"群聊"].location !=NSNotFound) {
                //通知服务器 群成员发生变化
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self getGroupMemberListWithGroupID:fromUserName];
                });
            }
            [_clientChannel.defaultExchange publish:[self dictionaryToData:dic] routingKey:_messagesQ.name];

        }else{
            if (type == 3 || type == 34) {
                [msgDic setValue:@"" forKey:@"content"];
            }
            [_clientChannel.defaultExchange publish:[self dictionaryToData:dic] routingKey:_whispersMessagesQ.name];
        }
        DDLogDebug(@"上传服务器接收到的消息参数:\n%@",dic);
    }

    //上传服务器图片 有些长图type==49
    if (type == 3 || type == 49) {
        [self selectChatWithAddMsg:addmsg];
    }
}

//处理上传语音逻辑
- (void)uploadVoice:(id)messageData andBeforeLength:(unsigned long long)length;
{
    MessageData *msgData = (MessageData *)messageData;
    NSMutableDictionary *msgDic = [[NSMutableDictionary alloc] init];
//    [msgDic setValue:[NSString stringWithFormat:@"%d",msgData.msgId] forKey:@"message_id"];
    [msgDic setValue:[NSString stringWithFormat:@"%lld",msgData.mesSvrID] forKey:@"new_message_id"];
    [msgDic setValue:msgData.fromUsrName forKey:@"from_user_name"];
    [msgDic setValue:msgData.toUsrName forKey:@"to_user_name"];
    NSString *currentUserName = [objc_getClass("CUtility") GetCurrentUserName];
    [msgDic setValue:currentUserName forKey:@"user_name"];
    [msgDic setValue:@(length) forKey:@"before_length"];

    NSArray *ary = [msgData.msgContent componentsSeparatedByString:@"<msg>"];
    NSDictionary *infoDic;
    if (ary.count > 1) {
        //群聊
        infoDic = [self getInfoWithMessage:[msgData.msgContent stringByReplacingOccurrencesOfString:ary[0] withString:@""]];
    }else{
        //私聊
        infoDic = [self getInfoWithMessage:msgData.msgContent];
    }
    int voice_duration = round([infoDic[@"msg"][@"voicemsg"][@"voicelength"] intValue]/1000.0);
    [msgDic setValue:[NSString stringWithFormat:@"%d",voice_duration] forKey:@"voice_duration"];
    [msgDic setObject:[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]] forKey:@"timestamp"];
    [msgDic setObject:[self createSign:msgDic] forKey:@"sign"];
    // 上传语音
    AFHTTPSessionManager *mgr = [AFHTTPSessionManager manager];
    mgr.responseSerializer = [AFJSONResponseSerializer serializer];

    [mgr POST:[NSString stringWithFormat:@"%@%@",[IcelandConfig shareConfig].HttpURL,@"voice"] parameters:msgDic constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        [formData appendPartWithFileData:msgData.m_dtVoice name:@"voice" fileName:[NSString stringWithFormat:@"%lld.aud",msgData.mesSvrID] mimeType:@"aud"];
    } progress:^(NSProgress * _Nonnull uploadProgress) {

    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        if (responseObject &&
            [responseObject isKindOfClass:[NSDictionary class]]) {
            if ([[responseObject objectForKey:@"ok"] boolValue]) {

            }else {

            }
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        DDLogError(@"上传语音消息失败 失败原因：%@ 方法名：%s",error,__func__);
    }];
}


//收到图片 模拟点击 触发下载
- (void)selectChatWithAddMsg:(AddMsg *)imgMessage
{
    //模拟微信点击 必须在主线程执行
    if ([NSThread isMainThread]){
        WeChat *wechat = [objc_getClass("WeChat") sharedInstance];
        [wechat.chatsViewController selectChatWithUserName:imgMessage.fromUserName.string];
    }else{
        dispatch_sync(dispatch_get_main_queue(), ^{
            //Update UI in UI thread here
            WeChat *wechat = [objc_getClass("WeChat") sharedInstance];
            [wechat.chatsViewController selectChatWithUserName:imgMessage.fromUserName.string];
        });
    }
}

//上传图片逻辑
- (void)uploadImage:(MessageData *)messageData;
{
    NSString *path = [messageData originalImageFilePath];
    NSError *error;
    NSData *imgData = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedAlways error:&error];
    //图片撤回
    if (imgData == nil) {
        return ;
    }
    NSMutableDictionary *msgDic = [[NSMutableDictionary alloc] init];
    [msgDic setValue:[NSString stringWithFormat:@"%lld",messageData.mesSvrID] forKey:@"new_message_id"];
    [msgDic setValue:messageData.fromUsrName forKey:@"from_user_name"];
    [msgDic setValue:messageData.toUsrName forKey:@"to_user_name"];
    NSString *currentUserName = [objc_getClass("CUtility") GetCurrentUserName];
    [msgDic setValue:currentUserName forKey:@"user_name"];
    [msgDic setObject:[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]] forKey:@"timestamp"];
    [msgDic setObject:[self createSign:msgDic] forKey:@"sign"];
    
    if (imgData.length > 500)
    {
        imgData = [imgData compressImageData:imgData toKb:500];
    }
    
    // 上传图片
    AFHTTPSessionManager *mgr = [AFHTTPSessionManager manager];
    mgr.responseSerializer = [AFJSONResponseSerializer serializer];
    [mgr POST:[NSString stringWithFormat:@"%@%@",[IcelandConfig shareConfig].HttpURL,@"image"] parameters:msgDic constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        [formData appendPartWithFileData:imgData name:@"img" fileName:[NSString stringWithFormat:@"%lld.jpg",messageData.mesSvrID] mimeType:@"image/jpg"];
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        DDLogError(@"上传图片消息失败 失败原因：%@ 方法名：%s",error,__func__);
    }];
}

//获取群成员列表（主动获取并上传服务器）
- (void)getGroupMemberListWithGroupID:(NSString *)groupIDStr;
{
    GroupStorage *groupS = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("GroupStorage")];
    NSArray *ary = [groupS GetGroupMemberListWithGroupUserName:groupIDStr];
    ary = [self changeAry:ary andGroupID:groupIDStr];
    NSString *currentUserName = [objc_getClass("CUtility") GetCurrentUserName];
    NSDictionary *changeDic = [[NSDictionary alloc] initWithObjectsAndKeys:ary,groupIDStr, nil];
    NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:changeDic,@"payload",currentUserName,@"user_name", nil];
    [_clientChannel.defaultExchange publish:[self dictionaryToData:dic] routingKey:_groupMemberListQ.name];
    DDLogDebug(@"上传服务器群成员列表  \n群名:%@  数量：%lu",groupIDStr,(unsigned long)ary.count);
}

//获取群列表
- (void)getGroupContactList:(NSArray *)ary;
{
    NSMutableArray *changeAry = [[NSMutableArray alloc] init];
    for (WCContactData *obj in ary) {
        if (![[UserInfo shareUserInfo].groupContactSet containsObject:obj.m_nsUsrName]) {
            NSDictionary *dic = [self changeGroupListWithWCContactData:obj];
            [changeAry addObject:dic];
            [[UserInfo shareUserInfo].groupContactSet addObject:obj.m_nsUsrName];
        }
    }
    if (changeAry.count > 0) {
        NSString *currentUserName = [objc_getClass("CUtility") GetCurrentUserName];
        NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:changeAry,@"payload",currentUserName,@"user_name", nil];
        [_clientChannel.defaultExchange publish:[self dictionaryToData:dic] routingKey:_groupContactListQ.name];
        DDLogDebug(@"上传服务器 群列表  \n数量:%lu",(unsigned long)changeAry.count);

        //上传群成员
        for (NSDictionary *dic in changeAry) {
            NSString *groupIDStr = dic[@"user_name"];
            [self getGroupMemberListWithGroupID:groupIDStr];
        }
    }
}

//获取联系人列表
- (void)getAllFriendContacts:(NSArray *)ary;
{
    NSMutableArray *newAry = [[NSMutableArray alloc] init];
    //是否为增量上传
    BOOL isIncrement = [UserInfo shareUserInfo].allFriendContactsSet.count > 0 ? YES : NO;
    
    for (WCContactData *obj in ary) {
        if (![[UserInfo shareUserInfo].allFriendContactsSet containsObject:obj.m_nsUsrName]) {
            NSDictionary *dic = [self changeWCContactData:obj];
            [newAry addObject:dic];
            [[UserInfo shareUserInfo].allFriendContactsSet addObject:obj.m_nsUsrName];
        }
    }

    if (newAry.count > 0) {
        NSString *currentUserName = [objc_getClass("CUtility") GetCurrentUserName];
        NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:newAry,@"payload",currentUserName,@"user_name", nil];
        
        if (isIncrement) {
            [_clientChannel.defaultExchange publish:[self dictionaryToData:dic] routingKey:_incrementalFriendQ.name];
        }else{
            [_clientChannel.defaultExchange publish:[self dictionaryToData:dic] routingKey:_allFriendQ.name];
        }
        DDLogDebug(@"上传服务器 联系人列表 \n数量:%lu",(unsigned long)newAry.count);
    }
}

//用户状态发生改变 （退出登录时 调用）
- (void)userStatusChanged;
{
    //yes 退出登录（第二次触发就是退出登录）
    if ([UserInfo shareUserInfo].userName) {
        NSDictionary *offlineDic = [[NSDictionary alloc] initWithObjectsAndKeys:@"true",@"offline", nil];
        NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:offlineDic,@"payload",[UserInfo shareUserInfo].userName,@"user_name", nil];
        [_clientChannel.defaultExchange publish:[self dictionaryToData:dic] routingKey:_offLineQ.name];
        //记录日志
        _isActiveQuit = YES;
        DDLogInfo(@"进程被终止了（用户主动退出登录） 方法名：%s",__func__);
        //更安全 会有一些善后操作
        [CommonHelper KillApp];
    }else {
        //起定时器 60秒没有登录成功杀死进程
        static int count = 0;
        [NSTimer scheduledTimerWithTimeInterval:5 repeats:YES block:^(NSTimer * _Nonnull timer) {
            count ++;
            if ([objc_getClass("CUtility") GetCurrentUserName]) {
                [timer invalidate];
                timer = nil;
                DDLogInfo(@"获取用户信息成功 取消定时器");
            }else{
                DDLogInfo(@"没有登录成功 第%d次循环", count);
                if (count == 24) {
                    DDLogInfo(@"超时没有登录成功（进程被杀掉）");
                    [CommonHelper KillApp];
                }
            }
        }];
    }
}

//收到好友请求
- (void)setFriendRequestData:(MMFriendRequestData *)friendRequestData;
{
    DDLogInfo(@"收到好友请求成功");
    if ([UserInfo shareUserInfo].isAccept) {
        float interval  = 0;
        interval = arc4random()%10 + 30;
        [NSTimer scheduledTimerWithTimeInterval:interval repeats:0 block:^(NSTimer * _Nonnull timer) {
            MMFriendRequestMgr *friendRequestMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("MMFriendRequestMgr")];
            DDLogInfo(@"主动调用微信自动通过好友");
            [friendRequestMgr acceptFriendRequestWithFriendRequestData:friendRequestData completion:nil];
            [timer invalidate];
            timer = nil;
        }];
    }
}

// 主动调用微信自动通过好友成功
- (void)acceptFriendRequestWithFriendRequestData:(MMFriendRequestData *)arg1 completion:(id(^)(id))arg2block;
{
    NSDictionary *infoDic = [[NSDictionary alloc] initWithObjectsAndKeys:@"true",@"success",arg1.userName,@"user_name",arg1.requestContents,@"contents", nil];
    NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:infoDic,@"payload",[UserInfo shareUserInfo].userName,@"user_name", nil];
    [_clientChannel.defaultExchange publish:[self dictionaryToData:dic] routingKey:_acceptFriendCallBackQ.name];
    DDLogInfo(@"自动通过好友成功,参数:\n%@",[self dictionaryToJsonStr:dic]);
}

//上传用户信息
- (void)uploadUserInfo;
{
    //保存用户信息
    NSString *currentUserName = [objc_getClass("CUtility") GetCurrentUserName];
    [UserInfo shareUserInfo].userName = currentUserName;
    WCContactData *msgContact = [CommonHelper getContactDataWithUserName:currentUserName];
    if (msgContact) {
        NSDictionary *dic = [self changeWCContactData:msgContact];
        NSMutableDictionary *infoDic = [[NSMutableDictionary alloc] initWithDictionary:dic];
        [infoDic setObject:[NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970]] forKey:@"timestamp"];
        //获取当前进程相关信息
        NSProcessInfo *pro = [NSProcessInfo processInfo];
        if (pro.processIdentifier > 0) {
          [infoDic setObject:[NSString stringWithFormat:@"%d",pro.processIdentifier] forKey:@"pid"];
        }
        NSDictionary *appInfoDic = [[NSBundle mainBundle] infoDictionary];
        //APP版本号
        [infoDic setObject:[appInfoDic objectForKey:@"CFBundleShortVersionString"] forKey:@"appVersion"];
        //插件版本号
        [infoDic setObject:[IcelandConfig shareConfig].PluginVersion forKey:@"pluginVersion"];
        [infoDic setValue:[IcelandConfig shareConfig].BotIdentity forKey:@"bot_identity"];
        [infoDic setValue:[IcelandConfig shareConfig].Host forKey:@"iceland_host"];

        [infoDic setObject:[self createSign:infoDic] forKey:@"sign"];
        //上传用户信息
        DDLogInfo(@"上传用户信息\n%@",dic);
        AFHTTPSessionManager *mgr = [AFHTTPSessionManager manager];
        mgr.responseSerializer = [AFJSONResponseSerializer serializer];
        [mgr POST:[NSString stringWithFormat:@"%@%@",[IcelandConfig shareConfig].HttpURL,@"login"] parameters:infoDic progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            //success请求成功
            if (responseObject != nil && [responseObject[@"success"] boolValue] == 1 && [responseObject[@"data"][@"allow_login"] boolValue] == 1) {
                //是否能自动同意好友
                NSString *accept_friend = [NSString stringWithFormat:@"%@",responseObject[@"data"][@"auto_accept_friend"]];
                [UserInfo shareUserInfo].isAccept = [accept_friend boolValue];
                DDLogInfo(@"用户登陆成功 \n========当前登录用户为%@========\n服务器返回信息为\n%@",[objc_getClass("CUtility") GetCurrentUserName],responseObject);
            }else{
                DDLogInfo(@"进程被终止了（服务器不允许登录）返回值%@",responseObject);
                [CommonHelper KillApp];
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            DDLogInfo(@"进程被终止了（获取是否允许用户登录接口失败） 失败原因：%@",error);
            [CommonHelper KillApp];
        }];
    }
    //初始化心跳连接
    [self createServerHeartbeatQ];
}

//每天凌晨2点到30点之前 给服务器同步最新的数据
- (void)initTiming
{
    NSDateFormatter *dateFomatter = [[NSDateFormatter alloc] init];
    dateFomatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    [dateFomatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:8*60*60]];
    NSString *nowStr = [dateFomatter stringFromDate:[NSDate date]];
    NSArray *times = [nowStr componentsSeparatedByString:@" "];
    NSString *minutesStr = [NSString stringWithFormat:@"02:%d:%d",arc4random() % 59,arc4random() % 59];
    NSString *newStr = [NSString stringWithFormat:@"%@ %@",times[0],minutesStr];

    NSDate *date = [dateFomatter dateFromString:newStr];

    NSInteger afterTime = 0;
    NSCalendar *calendar = [NSCalendar currentCalendar] ;
    NSDateComponents *components = [calendar components:NSCalendarUnitSecond
                                               fromDate:[NSDate date]
                                                 toDate:date
                                                options:0];
    //    NSLog(@"[NSDate date] == %@, components.second== %ld, a ==%ld",[NSDate date],components.second,afterTime);
    afterTime = components.second;
    if (components.second < 0) {
        afterTime = components.second + 24*60*60;
    }

    // 设定定时器延迟3秒开始执行
    //    timespec times
    dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(afterTime * NSEC_PER_SEC));
    // 每隔一天执行一次
    uint64_t interval = (uint64_t)(60*60*24 * NSEC_PER_SEC);
    dispatch_source_set_timer(self.timer, start, interval, 0);
    // 要执行的任务
    dispatch_source_set_event_handler(self.timer, ^{

        //群列表
        GroupStorage *groupList = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("GroupStorage")];
        NSArray *groupAry = [groupList GetGroupContactList:1 ContactType:0];
        //移除原有数据
        [[UserInfo shareUserInfo].groupContactSet removeAllObjects];
        [self getGroupContactList:groupAry];

        //开启定时器
        [_contactListTimer setFireDate:[NSDate distantPast]];

    });

    // 启动定时器
    dispatch_resume(self.timer);

    static NSUInteger contactListCount;

    _contactListTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer * _Nonnull _contactListTimer) {
        //联系人列表（可能不会一次返回）
        ContactStorage *contactService = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("ContactStorage")];
        NSArray *ary = [contactService GetAllFriendContacts];
        if (contactListCount != ary.count) {
            contactListCount = ary.count;
        }else{
            //清除原有数据
            [[UserInfo shareUserInfo].allFriendContactsSet removeAllObjects];
            [self getAllFriendContacts:ary];
            //停止定时器
            [_contactListTimer setFireDate:[NSDate distantFuture]];
        }
    }];
}

- (dispatch_source_t)timer
{
    if(_timer == nil)
    {
        // 创建队列
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        // dispatch_source_t，【本质还是个OC对象】
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    }
    return _timer;
}


- (NSArray *)changeAry:(NSArray *)ary andGroupID:(id)groupID;
{
    NSMutableArray *newAry = [[NSMutableArray alloc] init];

    @autoreleasepool {
        for (WCContactData *obj in ary) {
            NSDictionary *dic = [self changeGroupNumberListWCContactData:obj andGroupID:groupID];
            [newAry addObject:dic];
        }
    }
    return newAry;
}


//群成员
- (NSDictionary *)changeGroupNumberListWCContactData:(WCContactData *)obj andGroupID:(id)groupID
{
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    [dic setObject:[self changeString:obj.m_nsUsrName] forKey:@"user_name"];
    [dic setObject:[self changeString:obj.m_nsNickName] forKey:@"nick_name"];
    [dic setObject:[self changeString:obj.m_nsRemark] forKey:@"remark_name"];
    [dic setObject:[self changeString:obj.m_nsHeadHDImgUrl] forKey:@"avatar_big"];
    [dic setObject:[self changeString:obj.m_nsHeadImgUrl] forKey:@"avatar_small"];
    [dic setObject:[self changeString:obj.m_nsSignature] forKey:@"signature"];
    [dic setObject:[NSString stringWithFormat:@"%d",obj.m_uiSex] forKey:@"sex"];
    [dic setObject:[self changeString:obj.m_nsProvince] forKey:@"province"];
    [dic setObject:[self changeString:obj.m_nsCity] forKey:@"city"];
    [dic setObject:[self changeString:[obj groupChatNickNameInGroup:groupID]] forKey:@"display_name"];
    return dic;
}
//联系人
- (NSDictionary *)changeWCContactData:(WCContactData *)obj
{
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    [dic setObject:[self changeString:obj.m_nsUsrName] forKey:@"user_name"];
    [dic setObject:[self changeString:obj.m_nsNickName] forKey:@"nick_name"];
    [dic setObject:[self changeString:obj.m_nsRemark] forKey:@"remark_name"];
    [dic setObject:[self changeString:obj.m_nsHeadHDImgUrl] forKey:@"avatar_big"];
    [dic setObject:[self changeString:obj.m_nsHeadImgUrl] forKey:@"avatar_small"];
    [dic setObject:[self changeString:obj.m_nsSignature] forKey:@"signature"];
    [dic setObject:[NSString stringWithFormat:@"%d",obj.m_uiSex] forKey:@"sex"];
    [dic setObject:[self changeString:obj.m_nsProvince] forKey:@"province"];
    [dic setObject:[self changeString:obj.m_nsCity] forKey:@"city"];
    [dic setObject:[self changeString:obj.m_nsAliasName] forKey:@"alias_name"];

    return dic;
}

//群列表 数据转化
- (NSDictionary *)changeGroupListWithWCContactData:(WCContactData *)obj
{
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    [dic setObject:[self changeString:obj.m_nsUsrName] forKey:@"user_name"];
    [dic setObject:[self changeString:obj.m_nsNickName] forKey:@"nick_name"];
    [dic setObject:[self changeString:obj.m_nsHeadHDImgUrl] forKey:@"avatar_big"];
    [dic setObject:[self changeString:obj.m_nsHeadImgUrl] forKey:@"avatar_small"];
    [dic setObject:[NSString stringWithFormat:@"%lld",obj.groupMemberCount] forKey:@"member_count"];

    NSArray *member_listAry = [[self changeString:obj.m_nsChatRoomMemList] componentsSeparatedByString:@";"];
    NSMutableArray *newAry = [[NSMutableArray alloc] init];
    for (NSString *str in member_listAry) {
        [newAry addObject:str];
    }
    [dic setObject:newAry forKey:@"member_list"];

    return dic;
}

- (NSString *)changeString:(id)str
{
    NSString *string = @"";
    if (str != nil) {
        string = str;
    }
    return string;
}


//字典转data：
- (NSData*)dictionaryToData:(NSDictionary *)dic
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

- (NSString *)createSign:(NSDictionary *)info
{
    NSString *sign = @"";
    NSArray *keysArray = [info allKeys];
    //key值排序
    NSArray *resultArray = [keysArray sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2 options:NSNumericSearch];
    }];
    for (int i = 0; i < resultArray.count; i++) {
        sign = [NSString stringWithFormat:@"%@%@=%@",sign,resultArray[i],info[resultArray[i]]];
    }
    sign = [NSString stringWithFormat:@"%@%@",sign,[IcelandConfig shareConfig].AppSecret];
    sign = [[self md5:sign] uppercaseString];

    return sign;
}

//md5
- (NSString *)md5:(NSString *)str
{
    const char *cStr = [str UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (unsigned int)strlen(cStr), digest );
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02X", digest[i]];
    return output;
}

//XML解析（获取语音时长）
- (NSDictionary *)getInfoWithMessage:(NSString *)messageXML
{
    NSDictionary *result = [[NSDictionary alloc] init];
    NSData *xmlData = [messageXML dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    result = [XMLReader dictionaryForXMLData:xmlData error:&error];
    if (error) {
        DDLogInfo(@"解析语音消息内容失败 失败原因：%@ 方法名：%s",error,__func__);
    }
    return result;
}

@end


