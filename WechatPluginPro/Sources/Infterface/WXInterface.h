//
//  WXInterface.h
//  WechatPluginPro
//
//  Created by 刘伟 on 2017/12/11.
//  Copyright © 2017年 boohee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WCContactData.h"
#import <Cocoa/Cocoa.h>
#import <objc/message.h>

@interface MMLoginOneClickViewController : NSViewController
@property(nonatomic) __weak NSButton *unlinkButton; // @synthesize unlinkButton=_unlinkButton;
@property(nonatomic) __weak NSButton *loginButton; // @synthesize loginButton=_loginButton;
- (void)sendLoginConfirmReqeust;
- (void)onLoginButtonClicked:(id)arg1;
- (void)cleanupCGICallbacks;
- (void)viewDidLoad;
@end

@interface MMLoginViewController : NSObject
@property(retain, nonatomic) MMLoginOneClickViewController *oneClickViewController; // @synthesize oneClickViewController=_oneClickViewController;
@end

@interface MMMainWindowController : NSWindowController
@property(retain, nonatomic) MMLoginViewController *loginViewController;
- (void)onAuthOK;
- (void)onLogOut;
@end

@interface MMChatsViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>
@property(nonatomic) __weak NSTableView *tableView;
- (void)selectChatWithUserName:(id)arg1;
- (void)tableView:(id)arg1 rowGotMouseDown:(long long)arg2;
- (id)tableView:(id)arg1 viewForTableColumn:(id)arg2 row:(long long)arg3;
@end

@interface MMSessionInfoPackedInfo: NSObject
@property(retain, nonatomic) WCContactData *m_contact;
@end

@interface MMSessionInfo : NSObject
@property BOOL m_bIsTop;
@property(retain, nonatomic) NSString *m_nsUserName;
@property(retain, nonatomic) MMSessionInfoPackedInfo *m_packedInfo;
@end

@interface MMChatsTableCellView : NSTableCellView
@property(retain, nonatomic) MMSessionInfo *sessionInfo; // @synthesize sessionInfo=_sessionInfo;
@end

@interface MMSessionMgr : NSObject
- (id)GetAllSessions;
- (id)getContact:(id)arg1;
@end

@interface WeChat : NSObject

+ (id)sharedInstance;
@property(nonatomic) MMChatsViewController *chatsViewController;
@property(retain, nonatomic) MMMainWindowController *mainWindowController;
@property(nonatomic) BOOL isAppTerminating;
@end

@interface AccountService : NSObject
- (void)ClearLastdLoginInfo;
- (void)ClearLastLoginAutoAuthKey;
- (void)onGetOnlineInfoFinished;
- (BOOL)canAutoAuth;
- (void)AutoAuth;
- (void)ManualLogout;
- (id)GetLastLoginUserName;
- (id)GetCurUserName;
@end

@interface MMLocalDefaults : NSObject
+ (void)registerDefaults:(id)arg1;
+ (void)cleanUpForLogOut;
+ (id)currentUserDefaults;
+ (void)initialize;

- (void)setData:(id)arg1 forKey:(id)arg2;
- (id)dataForKey:(id)arg1;
- (void)setString:(id)arg1 forKey:(id)arg2;
- (id)stringForKey:(id)arg1;
- (void)setBool:(BOOL)arg1 forKey:(id)arg2;
- (BOOL)boolForKey:(id)arg1;
- (void)setInteger:(long long)arg1 forKey:(id)arg2;
- (long long)integerForKey:(id)arg1;
- (void)setObject:(id)arg1 forKey:(id)arg2;
- (id)objectForKey:(id)arg1;
- (void)_appWillTerminate:(id)arg1;
- (BOOL)synchronize;
- (void)asynchronize;
- (id)filePath;
- (void)dealloc;
- (id)initWithUsername:(id)arg1;
@end


@interface SKBuiltinString_t : NSObject
@property(retain, nonatomic, setter=SetString:) NSString *string; // @synthesize string;
@end

@interface SKBuiltinBuffer_t : NSObject
@property(retain, nonatomic, setter=SetBuffer:) NSData *buffer; // @synthesize buffer;
@end

@interface AddMsg : NSObject
@property(retain, nonatomic, setter=SetContent:) SKBuiltinString_t *content;
@property(retain, nonatomic, setter=SetFromUserName:) SKBuiltinString_t *fromUserName;
@property(nonatomic, setter=SetMsgType:) int msgType;
@property(retain, nonatomic, setter=SetToUserName:) SKBuiltinString_t *toUserName;
@property (nonatomic, assign) unsigned int createTime;
@property(nonatomic, setter=SetMsgId:) int msgId; // @synthesize msgId;
@property(nonatomic, setter=SetNewMsgId:) long long newMsgId; // @synthesize newMsgId;
@property(nonatomic, setter=SetMsgSource:) NSString *msgSource; // @synthesize newMsgId;
@property(nonatomic, setter=SetImgBuf:) SKBuiltinBuffer_t *imgBuf; // @synthesize newMsgId;
@property(nonatomic, setter=SetMsgSeq:) unsigned int msgSeq; // @synthesize msgSeq;
@end

@interface MessageService : NSObject
- (void)onRevokeMsg:(id)arg1;
- (void)OnSyncBatchAddMsgs:(NSArray *)arg1 isFirstSync:(BOOL)arg2;
- (id)SendTextMessage:(id)arg1 toUsrName:(id)arg2 msgText:(id)arg3 atUserList:(id)arg4;
- (id)getMsgDBWithIdentifier:(id)arg1;
- (id)getMsgDB:(id)arg1;
- (void)AddLocalMsg:(id)arg1 msgData:(id)arg2;
- (id)genMsgDataFromAddMsg:(id)arg1;
//图片消息
- (id)SendImgMessage:(id)arg1 toUsrName:(id)arg2 thumbImgData:(id)arg3 midImgData:(id)arg4 imgData:(id)arg5 imgInfo:(id)arg6;
- (void)StartDownloadAppMsg:(id)arg1 msgData:(id)arg2;
- (void)onVoiceDowloadFinished:(id)arg1 isSuccess:(BOOL)arg2 isNeedSave:(BOOL)arg3 offset:(unsigned long long)arg4;
@end

@interface MMServiceCenter : NSObject
+ (id)defaultCenter;
- (id)getService:(Class)arg1;
@end

@interface CUtility : NSObject
+ (BOOL)HasWechatInstance;
+ (unsigned long long)getFreeDiskSpace;
+ (void)ReloadSessionForMsgSync;
+ (id)GetCurrentUserName;
+ (void)KernelRemoveUserPrivacyFilesWithUserName:(id)arg1;
@end

@interface PBGeneratedMessage : NSObject

@end

@interface VerifyUser : PBGeneratedMessage
- (id)mergeFromCodedInputStream:(id)arg1;
@end

@interface VerifyUserRequest : PBGeneratedMessage
- (void)addVerifyUserList:(id)arg1;
- (void)addVerifyUserListFromArray:(id)arg1;
@end

@interface MMFriendRequestMgr : NSObject
- (void)acceptFriendRequestWithFriendRequestData:(id)arg1 completion:(id(^)(id))arg2block;
@end

@interface MMFriendRequestData : NSObject
@property(nonatomic) unsigned int opCode; // @synthesize opCode;
@property(nonatomic) unsigned int scene; // @synthesize scene;
@property(retain, nonatomic) NSString *ticket; // @synthesize ticket;
@property(retain, nonatomic) NSString *encryptuserName; // @synthesize encryptuserName;
@property(nonatomic) BOOL hasReadRequest; // @synthesize hasReadRequest;
@property(retain, nonatomic) NSString *userSignature; // @synthesize userSignature;
@property(retain, nonatomic) NSString *region; // @synthesize region;
@property(retain, nonatomic) NSMutableArray *requestContents; // @synthesize requestContents;
@property(retain, nonatomic) NSString *nickName; // @synthesize nickName;
@property(retain, nonatomic) NSString *userName; // @synthesize userName;
// Remaining properties
@property(readonly, copy) NSString *description;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;
- (id)initWithDictionary:(id)arg1;
@end

@interface MMFriendRequestCellView : NSUnit
- (void)acceptFriend:(id)arg1;
@end

@interface GroupStorage : NSObject
- (NSArray *)GetGroupMemberListWithGroupUserName:(id)arg1;
- (NSArray *)GetGroupMemberListWithGroupUserName:(id)arg1 limit:(unsigned int)arg2;
- (NSArray *)GetGroupContactList:(unsigned int)arg1 ContactType:(unsigned int)arg2;
- (BOOL)InviteGroupMemberWithChatRoomName:(NSString *)arg1 memberList:(NSArray *)arg2 completion:(id(^)(id))arg2block;
- (BOOL)AddGroupMembers:(NSArray *)arg1 withGroupUserName:(NSString *)arg2 completion:(id(^)(id))arg3;
- (BOOL)DeleteGroupMemberWithGroupUserName:(id)arg1 memberUserNameList:(id)arg2 completion:(id)arg3;
@end

@interface ContactStorage : NSObject
- (NSArray *)GetAllFriendContacts;
- (id)GetContactList:(unsigned int)arg1 ContactType:(unsigned int)arg2;
- (BOOL)addOpLog_ModifyContact:(id)arg1 sync:(BOOL)arg2;
- (BOOL)loadContactsWithType:(unsigned int)arg1;
@end

@interface GroupMember : NSObject
@property(copy, nonatomic) NSString *m_nsSignature; // @synthesize m_nsSignature=_m_nsSignature;
@property(copy, nonatomic) NSString *m_nsCity; // @synthesize m_nsCity=_m_nsCity;
@property(copy, nonatomic) NSString *m_nsProvince; // @synthesize m_nsProvince=_m_nsProvince;
@property(copy, nonatomic) NSString *m_nsCountry; // @synthesize m_nsCountry=_m_nsCountry;
@property(copy, nonatomic) NSString *m_nsRemarkFullPY; // @synthesize m_nsRemarkFullPY=_m_nsRemarkFullPY;
@property(copy, nonatomic) NSString *m_nsRemarkShortPY; // @synthesize m_nsRemarkShortPY=_m_nsRemarkShortPY;
@property(copy, nonatomic) NSString *m_nsRemark; // @synthesize m_nsRemark=_m_nsRemark;
@property(nonatomic) unsigned int m_uiSex; // @synthesize m_uiSex=_m_uiSex;
@property(copy, nonatomic) NSString *m_nsFullPY; // @synthesize m_nsFullPY=_m_nsFullPY;
@property(copy, nonatomic) NSString *m_nsNickName; // @synthesize m_nsNickName=_m_nsNickName;
@property(nonatomic) unsigned int m_uiMemberStatus; // @synthesize m_uiMemberStatus=_m_uiMemberStatus;
@property(copy, nonatomic) NSString *m_nsMemberName; // @synthesize m_nsMemberName=_m_nsMemberName;
@end

@interface MMContactsDetailViewController : NSObject
- (void)addRemark:(id)arg1 valueText:(id)arg2;
@end

typedef void(^QRBlock)(id argarg1);
@interface QRCodeLoginCGI : NSObject
- (void)getQRCodeWithCompletion:(QRBlock)arg1;
@end

@interface MMChatRoomInfoDetailCGI : NSObject
- (void)setChatRoomAnnouncementWithUserName:(id)arg1 announceContent:(id)arg2 withCompletion:(id)arg3;
@end

@interface LogoutCGI : NSObject
- (void)sendLogoutCGIWithCompletion:(id)arg1;
- (void)ClearData;
@end

@interface Reachability : NSObject
- (BOOL)startNotifier;
@end

@interface MessageData : NSObject
@property(retain, nonatomic) NSData *m_dtImg; // @dynamic m_dtImg;
@property(copy, nonatomic) NSString *m_nsImgHDUrl; // @dynamic m_nsImgHDUrl;
@property(retain, nonatomic) NSData *m_dtVoice; // @dynamic m_dtVoice;
@property(nonatomic) long long mesSvrID; // @synthesize mesSvrID;
@property(retain, nonatomic) NSString *toUsrName; // @synthesize toUsrName;
@property(retain, nonatomic) NSString *fromUsrName; // @synthesize fromUsrName;
@property(retain, nonatomic) NSString *msgContent; // @synthesize msgContent;
@property(nonatomic) unsigned int m_uiVoiceTime; // @dynamic m_uiVoiceTime;
@property(nonatomic) unsigned int messageType; // @synthesize messageType;

- (id)originalImageFilePath;
- (id)thumbnailImageFilePath;
- (id)videoFilePath;
@end

@interface ImgDownloadTask : NSObject
//- (void)startDownloading;
//- (void)downloadImgByCDN;
//- (void)downloadImg;
- (void)sendImgDownloadReq;
//- (void)onImgDownloadFinish:(id)arg1 isSuccess:(BOOL)arg2;
@end

@interface UploadMsgImgResponse : NSObject
- (id)mergeFromCodedInputStream:(id)arg1;
- (void)writeToCodedOutputStream:(id)arg1;
@end

@interface SendImageInfo : NSObject
@property(retain, nonatomic) NSURL *m_nuImageSourceURL; // @synthesize m_nuImageSourceURL=_m_nuImageSourceURL;
@property(nonatomic) unsigned int m_uiOriginalHeight; // @synthesize m_uiOriginalHeight=_m_uiOriginalHeight;
@property(nonatomic) unsigned int m_uiOriginalWidth; // @synthesize m_uiOriginalWidth=_m_uiOriginalWidth;
@property(nonatomic) unsigned int m_uiThumbHeight; // @synthesize m_uiThumbHeight=_m_uiThumbHeight;
@property(nonatomic) unsigned int m_uiThumbWidth; // @synthesize m_uiThumbWidth=_m_uiThumbWidth;
@property(nonatomic) unsigned int m_uiImageSource;
@end

@interface NSImage (Message)
typedef void(^MidRBlock)(id argarg1);
- (id)thumbnailDataWithSize:(struct CGSize)arg1;
- (id)thumbnailDataForMessage;
- (void)middleImageDataWithCompletion:(MidRBlock)arg1;
@end

@interface MessageThumbData : NSObject
@property(retain, nonatomic) NSData *data;
@end

@interface NSImage (Decompress)
+ (id)getDecodedImageWithData:(id)arg1;
+ (id)getDecodedImageWithFile:(id)arg1;
@end

@interface NSImage (Extend)
- (id)JPEGRepresentation;
- (id)kernelGenJPGRepresentation;
@end

@interface MMMessageCacheMgr:NSObject
- (void)downloadImageFinishedWithMessage:(id)arg1 type:(int)arg2 isSuccess:(BOOL)arg3;
@end

