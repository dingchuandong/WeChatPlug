//
//  CallServerHelper.m
//  WechatPluginPro
//
//  Created by dcd on 2017/12/14.
//  Copyright © 2017年 刘伟. All rights reserved.
//

#import "CallServerHelper.h"
#import <AppKit/AppKit.h>
#import <AFNetworking.h>
#import <CommonCrypto/CommonCrypto.h>
#import "WriteLogHandler.h"

@implementation CallServerHelper


-(instancetype)init
{
    if (self=[super init]) {
        
        //初始化链接
//        RMQConnection *conn = [[RMQConnection alloc] initWithUri:[UserInfo shareUserInfo].RabbitMQURL delegate:[RMQConnectionDelegateLogger new]];
        RMQTLSOptions *tlsOptions = [RMQTLSOptions fromURI:[UserInfo shareUserInfo].RabbitMQURL verifyPeer:NO];
        RMQConnection *conn = [[RMQConnection alloc] initWithUri:[UserInfo shareUserInfo].RabbitMQURL tlsOptions:tlsOptions channelMax:@65535 frameMax:@131072 heartbeat:@0 syncTimeout:@30 delegate:[RMQConnectionDelegateLogger new] delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) recoverAfter:@4 recoveryAttempts:@(NSUIntegerMax) recoverFromConnectionClose:YES];
        _ch = [conn createChannel];
        
        _QRCodeQ = [_ch queue:@"iceberg.login_qrcode" options:RMQQueueDeclareDurable];
//        _QRCodeQ.
        _AllFriendQ = [_ch queue:@"iceberg.contacts" options:RMQQueueDeclareDurable];
        _GroupContactListQ = [_ch queue:@"iceberg.rooms" options:RMQQueueDeclareDurable];
        _GroupMemberListQ = [_ch queue:@"iceberg.room_members" options:RMQQueueDeclareDurable];
        _WhispersMessagesQ = [_ch queue:@"iceberg.whispers" options:RMQQueueDeclareDurable];
        _MessagesQ = [_ch queue:@"iceberg.messages" options:RMQQueueDeclareDurable];
        _OffLineQ = [_ch queue:@"iceberg.offline" options:RMQQueueDeclareDurable];
        _AcceptFriendCallBackQ = [_ch queue:@"iceberg.accept_friend_callback" options:RMQQueueDeclareDurable];
        _ServerHeartbeatQ = [_ch queue:@"iceberg.heartbeat" options:RMQQueueDeclareDurable];
        
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
        // dispatch_source_t，【本质还是个OC对象】
        _heartbeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    }
    

    dispatch_source_set_timer(_heartbeatTimer, DISPATCH_TIME_NOW, 2 * 60 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(_heartbeatTimer, ^{
        NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:[NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970]],@"timestamp", nil];
        
        NSString *currentUserName = [objc_getClass("CUtility") GetCurrentUserName];
        if (currentUserName) {
            NSDictionary *infoDic = [[NSDictionary alloc] initWithObjectsAndKeys:currentUserName,@"user_name",dic,@"payload", nil];
            [_ch.defaultExchange publish:[self dictionaryToData:infoDic] routingKey:_ServerHeartbeatQ.name];
        }else{
            [[WriteLogHandler shareLogHander] writefile:[NSString stringWithFormat:@"进程被kill了 方法名：%s",__func__]];
            abort();
        }
    });
    dispatch_resume(_heartbeatTimer);
}

//获取登录的二维码
- (void)GetQRCodeWithCompletion:(NSImage *)arg1;
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
    
    [_ch.defaultExchange publish:imageData1 routingKey:_QRCodeQ.name];
    
}


//发送消息
- (void)SendTextMessage:(id)arg1 toUsrName:(id)arg2 msgText:(id)arg3 atUserList:(id)arg4;
{
    //    NSLog(@"发送到服务器啦 === 发送消息");
}

//接收到新消息
- (void)BatchAddMsgs:(NSArray *)msgs isFirstSync:(BOOL)arg2;
{
    for (AddMsg *addmsg in msgs) {
        [self UploadMessage:addmsg];
    }
}

- (void)UploadMessage:(AddMsg *)addmsg
{
    NSString *content = addmsg.content.string;
    NSString *fromUserName = addmsg.fromUserName.string;
    int type = addmsg.msgType;
    
    if (type == 1 || type == 10000 || type == 3) {
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
                [msgDic setValue:strAry[1] forKey:@"content"];
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
            if (type == 3) {
                [msgDic setValue:@"" forKey:@"content"];
            }
            //表示群成员发生了改变
            if (type == 10000 && [content rangeOfString:@"群聊"].location !=NSNotFound) {
                //通知服务器 群成员发生变化
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self GetGroupMemberListWithGroupID:fromUserName];
                });
            }
            
            [_ch.defaultExchange publish:[self dictionaryToData:dic] routingKey:_MessagesQ.name];
        }else{
            if (type == 3) {
                [msgDic setValue:@"" forKey:@"content"];
            }
            [_ch.defaultExchange publish:[self dictionaryToData:dic] routingKey:_WhispersMessagesQ.name];
            
//            [[WriteLogHandler shareLogHander] writefile:[NSString stringWithFormat:@"方法名：%s\n行数：%s",__func__,__FILE__]];

        }
    }
    
    //上传服务器图片
    if (type == 3) {
        [self UpLoadImg:addmsg];
    }
}

//处理上传图片的逻辑
- (void)UpLoadImg:(AddMsg *)imgMessage
{
    //模拟微信点击 必须在主线程执行
    if ([NSThread isMainThread])
    {
        WeChat *wechat = [objc_getClass("WeChat") sharedInstance];
        [wechat.chatsViewController selectChatWithUserName:imgMessage.fromUserName.string];
    }else{
        dispatch_sync(dispatch_get_main_queue(), ^{
            //Update UI in UI thread here
            WeChat *wechat = [objc_getClass("WeChat") sharedInstance];
            [wechat.chatsViewController selectChatWithUserName:imgMessage.fromUserName.string];
        });
    }
    
    MessageService *msgService = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("MessageService")];
    MessageData *msgData = [msgService genMsgDataFromAddMsg:imgMessage];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        NSString *path = [msgData originalImageFilePath];
        //微信对图片重命名了 实际的文件名称跟这个不一致/(ㄒoㄒ)/~~(01513932866_.pic_thumb.jpg == 331513932866_.pic_thumb.jpg)
        NSArray *pathAry = [path componentsSeparatedByString:@"/"];
        NSString *imgName = pathAry[pathAry.count - 1];
        NSString *folderName = [path stringByReplacingOccurrencesOfString:imgName withString:@""];
        if (imgName.length > 11) {
            imgName = [imgName substringWithRange:NSMakeRange(1, 10)];
        }
        NSFileManager *manager = [NSFileManager defaultManager];
        //3.获取文件夹下所有的子路径
        NSArray *allPath =[manager subpathsAtPath:folderName];
        //4.遍历所有的子路径
        for (NSString *subPath in allPath) {
            if ([subPath containsString:imgName]) {
                imgName = subPath;
                break;
            }
        }
        NSString *realImagName = [imgName stringByReplacingOccurrencesOfString:@".pic_thumb." withString:@".pic."];
        path = [folderName stringByAppendingPathComponent:realImagName];
        NSError *error;
        NSData *imgData = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedAlways error:&error];
        //说明只有小图
        if (imgData == nil) {
            path = [folderName stringByAppendingPathComponent:imgName];
            imgData = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedAlways error:&error];
        }
        
        //图片撤回
        if (imgData == nil) {
            return ;
        }
        
        NSMutableDictionary *msgDic = [[NSMutableDictionary alloc] init];
        [msgDic setValue:[NSString stringWithFormat:@"%d",imgMessage.msgId] forKey:@"message_id"];
        [msgDic setValue:[NSString stringWithFormat:@"%lld",imgMessage.newMsgId] forKey:@"new_message_id"];
        [msgDic setValue:imgMessage.fromUserName.string forKey:@"from_user_name"];
        [msgDic setValue:imgMessage.toUserName.string forKey:@"to_user_name"];
        NSString *currentUserName = [objc_getClass("CUtility") GetCurrentUserName];
        [msgDic setValue:currentUserName forKey:@"user_name"];
        
        [msgDic setObject:[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]] forKey:@"timestamp"];
        [msgDic setObject:[self createSign:msgDic] forKey:@"sign"];
        // 上传图片
        AFHTTPSessionManager *mgr = [AFHTTPSessionManager manager];
        mgr.responseSerializer = [AFJSONResponseSerializer serializer];
        
        [mgr POST:[NSString stringWithFormat:@"%@%@",[UserInfo shareUserInfo].HttpURL,@"image"] parameters:msgDic constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
            [formData appendPartWithFileData:imgData name:@"img" fileName:[NSString stringWithFormat:@"%d.jpg",imgMessage.msgId] mimeType:@"image/jpg"];
        } progress:^(NSProgress * _Nonnull uploadProgress) {
            
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
            if (responseObject &&
                [responseObject isKindOfClass:[NSDictionary class]]) {
                if ([[responseObject objectForKey:@"ok"] boolValue]) {
                    
                }else {
                    
                }
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
//            NSLog(@"%@",error);
        }];
    });
}

//获取群成员列表
- (void)GetGroupMemberListWithGroupUserName:(NSArray *)ary andGroupID:(NSString *)groupIDStr;
{
    //没有保存到通讯录的群 也会在这里面出现
    if (![[UserInfo shareUserInfo].groupMemberDic.allKeys containsObject:groupIDStr] && [[UserInfo shareUserInfo].groupContactDic.allKeys containsObject:groupIDStr]) {
        NSArray *newAry = [self changeAry:ary andGroupID:groupIDStr];
        [[UserInfo shareUserInfo].groupMemberDic setObject:newAry forKey:groupIDStr];
    }
}

//获取群成员列表（主动获取并上传服务器）
- (void)GetGroupMemberListWithGroupID:(NSString *)groupIDStr;
{
    GroupStorage *groupS = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("GroupStorage")];
    NSArray *ary = [groupS GetGroupMemberListWithGroupUserName:groupIDStr];
    ary = [self changeAry:ary andGroupID:groupIDStr];
    NSString *currentUserName = [objc_getClass("CUtility") GetCurrentUserName];
    NSDictionary *changeDic = [[NSDictionary alloc] initWithObjectsAndKeys:ary,groupIDStr, nil];
    NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:changeDic,@"payload",currentUserName,@"user_name", nil];
    [_ch.defaultExchange publish:[self dictionaryToData:dic] routingKey:_GroupMemberListQ.name];
}

//获取群列表
- (void)GetGroupContactList:(NSArray *)ary;
{
    NSMutableArray *changeAry = [[NSMutableArray alloc] init];
    for (WCContactData *obj in ary) {
        if (![[[UserInfo shareUserInfo].groupContactDic allKeys] containsObject:obj.m_nsUsrName]) {
            NSDictionary *dic = [self changeGroupListWithWCContactData:obj];
            [changeAry addObject:dic];
            [[UserInfo shareUserInfo].groupContactDic setObject:obj forKey:obj.m_nsUsrName];
        }
    }
    if (changeAry.count > 0) {
        NSString *currentUserName = [objc_getClass("CUtility") GetCurrentUserName];
        NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:changeAry,@"payload",currentUserName,@"user_name", nil];
        [_ch.defaultExchange publish:[self dictionaryToData:dic] routingKey:_GroupContactListQ.name];
        
        //上传群成员
        for (NSDictionary *dic in changeAry) {
            NSString *groupIDStr = dic[@"user_name"];
            [self GetGroupMemberListWithGroupID:groupIDStr];
        }
    }
}

//获取联系人列表
- (void)GetAllFriendContacts:(NSArray *)ary;
{
    //需要存储对象到本地 修改备注试要用
    //    if (_isFinishedLoad) {
    NSMutableArray *newAry = [[NSMutableArray alloc] init];
    
    for (WCContactData *obj in ary) {
        if (![[[UserInfo shareUserInfo].allFriendContactsDic allKeys] containsObject:obj.m_nsUsrName]) {
            NSDictionary *dic = [self changeWCContactData:obj];
            [newAry addObject:dic];
            [[UserInfo shareUserInfo].allFriendContactsDic setObject:obj forKey:obj.m_nsUsrName];
        }
    }
    if (newAry.count > 0) {
        NSString *currentUserName = [objc_getClass("CUtility") GetCurrentUserName];
        
        NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:newAry,@"payload",currentUserName,@"user_name", nil];
        [_ch.defaultExchange publish:[self dictionaryToData:dic] routingKey:_AllFriendQ.name];
    }
}

//用户状态发生改变 （退出登录时 调用） 
- (void)StartNotifier:(BOOL)arg1;
{
    
    //yes 退出登录（第二次触发就是退出登录）
    if ([UserInfo shareUserInfo].userName) {
        
        NSDictionary *offlineDic = [[NSDictionary alloc] initWithObjectsAndKeys:@"true",@"offline", nil];
        NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:offlineDic,@"payload",[UserInfo shareUserInfo].userName,@"user_name", nil];
        [_ch.defaultExchange publish:[self dictionaryToData:dic] routingKey:_OffLineQ.name];
        
        //记录日志
        [[WriteLogHandler shareLogHander] writefile:[NSString stringWithFormat:@"方法名:%s,参数:%@",__func__,[self dictionaryToJsonStr:dic]]];
        _isActiveQuit = YES;
        //延时五秒 杀死进程（五秒是为微信预留的处理后事时间）
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[WriteLogHandler shareLogHander] writefile:[NSString stringWithFormat:@"进程被kill了 方法名：%s",__func__]];
            abort();
        });
        //刚登陆第一次触发时
    }else {
        
       [objc_getClass("CUtility") getFreeDiskSpace];
        //清除本地用户数据
        if ([objc_getClass("CUtility") GetCurrentUserName]) {
            [objc_getClass("CUtility") KernelRemoveUserPrivacyFilesWithUserName:[objc_getClass("CUtility") GetCurrentUserName]];
        }
        //起定时器 60秒没有登录成功杀死进程
        static int count = 0;
        [NSTimer scheduledTimerWithTimeInterval:5 repeats:YES block:^(NSTimer * _Nonnull timer) {
            count ++;
            if ([objc_getClass("CUtility") GetCurrentUserName]) {
                [timer invalidate];
                timer = nil;
            }else{
                if (count == 12) {
                    [[WriteLogHandler shareLogHander] writefile:[NSString stringWithFormat:@"进程被kill了 方法名：%s",__func__]];
                    abort();
                }
            }
        }];
    }
}

//收到好友请求
- (void)InitWithDictionary:(id)arg1;
{
    if ([UserInfo shareUserInfo].isAccept) {
        float interval  = 0;
        interval = arc4random()%10 + 30;
        [NSTimer scheduledTimerWithTimeInterval:interval repeats:0 block:^(NSTimer * _Nonnull timer) {
            MMFriendRequestMgr *friendRequestMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("MMFriendRequestMgr")];
            id arg222;
            [friendRequestMgr acceptFriendRequestWithFriendRequestData:arg1 completion:arg222];
            [timer invalidate];
            timer = nil;
        }];
    }
}

// 拦截确认好友方法
- (id)AcceptFriendRequestWithFriendRequestData:(MMFriendRequestData *)arg1 completion:(id(^)(id))arg2block;
{
    NSDictionary *offlineDic = [[NSDictionary alloc] initWithObjectsAndKeys:@"true",@"success",arg1.userName,@"user_name",arg1.requestContents,@"contents", nil];
    NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:offlineDic,@"payload",[UserInfo shareUserInfo].userName,@"user_name", nil];
    [_ch.defaultExchange publish:[self dictionaryToData:dic] routingKey:_AcceptFriendCallBackQ.name];
    //记录日志
    [[WriteLogHandler shareLogHander] writefile:[NSString stringWithFormat:@"方法名:%s,参数:%@",__func__,[self dictionaryToJsonStr:dic]]];
    return nil;
}

//设置标识
- (void)setisFinishedLoad: (BOOL)arg1;
{
    _isFinishedLoad = arg1;
    //保存用户信息
    NSString *currentUserName = [objc_getClass("CUtility") GetCurrentUserName];
    [UserInfo shareUserInfo].userName = currentUserName;
    if ([[[UserInfo shareUserInfo].allFriendContactsDic allKeys] containsObject:currentUserName]) {
        NSDictionary *dic = [self changeWCContactData:[[UserInfo shareUserInfo].allFriendContactsDic objectForKey:currentUserName]];
        NSLog(@"%@",dic);
        NSMutableDictionary *infoDic = [[NSMutableDictionary alloc] initWithDictionary:dic];
        [infoDic setObject:[NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970]] forKey:@"timestamp"];
        [infoDic setObject:[self createSign:infoDic] forKey:@"sign"];
        //上传用户信息
        AFHTTPSessionManager *mgr = [AFHTTPSessionManager manager];
        mgr.responseSerializer = [AFJSONResponseSerializer serializer];
        [mgr POST:[NSString stringWithFormat:@"%@%@",[UserInfo shareUserInfo].HttpURL,@"login"] parameters:infoDic progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            //success请求成功
            if (responseObject != nil && [responseObject[@"success"] boolValue] == 1 && [responseObject[@"data"][@"allow_login"] boolValue] == 1) {
                //是否能自动同意好友
                NSString *accept_friend = [NSString stringWithFormat:@"%@",responseObject[@"data"][@"auto_accept_friend"]];
                [UserInfo shareUserInfo].isAccept = [accept_friend boolValue];
                
            }else{
                [[WriteLogHandler shareLogHander] writefile:[NSString stringWithFormat:@"进程被kill了(不允许登录) 方法名：%s",__func__]];
                abort();
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [[WriteLogHandler shareLogHander] writefile:[NSString stringWithFormat:@"进程被kill了 方法名：%s",__func__]];
            abort();
        }];
    }
    //初始化心跳连接
    [self createServerHeartbeatQ];
    //初始化日志文件
    [[WriteLogHandler shareLogHander] writefile:@"初始化日志文件"];
}


//每天凌晨3：30 给服务器同步最新的数据
- (void)initTiming
{
    NSDateFormatter *dateFomatter = [[NSDateFormatter alloc] init];
    dateFomatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    [dateFomatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:8*60*60]];
    NSString *nowStr = [dateFomatter stringFromDate:[NSDate date]];
    NSArray *times = [nowStr componentsSeparatedByString:@" "];
    NSString *newStr = [NSString stringWithFormat:@"%@ %@",times[0],@"03:30:00"];
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
        [[UserInfo shareUserInfo].groupContactDic removeAllObjects];
        [self GetGroupContactList:groupAry];
        
        //开启定时器
        [_contactListTimer setFireDate:[NSDate distantPast]];
        
    });
    
    // 启动定时器
    dispatch_resume(self.timer);
    
    static NSUInteger contactListCount;
    
    _contactListTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer * _Nonnull _contactListTimer) {
        //联系人列表（可能不会一次返回）
        ContactStorage *contactList = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("ContactStorage")];
        NSArray *ary = [contactList GetAllFriendContacts];
        if (contactListCount != ary.count) {
            contactListCount = ary.count;
        }else{
            //清除原有数据
            [[UserInfo shareUserInfo].allFriendContactsDic removeAllObjects];
            [self GetAllFriendContacts:ary];
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
    sign = [NSString stringWithFormat:@"%@%@",sign,[UserInfo shareUserInfo].AppSecret];
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

@end


