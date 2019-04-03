//
//  WCContactData.h
//  WechatPluginPro
//
//  Created by 刘伟 on 2017/12/7.
//  Copyright © 2017年 boohee. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WCContactData : NSObject<NSCoding>

@property(retain, nonatomic) NSString *m_nsNormalizeNamePY; // @synthesize m_nsNormalizeNamePY=_m_nsNormalizeNamePY;
@property(retain, nonatomic) NSData *m_dtUsrImg; // @synthesize m_dtUsrImg=_m_dtUsrImg;
//@property(retain, nonatomic) ChatRoomData *m_chatRoomData; // @synthesize m_chatRoomData;
@property(retain, nonatomic) NSDictionary *m_externalInfoJSONCache; // @synthesize m_externalInfoJSONCache;
@property(nonatomic) long long __rowID; // @synthesize __rowID=m___rowID;
@property(retain, nonatomic) NSString *m_nsAntispamTicket; // @synthesize m_nsAntispamTicket;
@property(nonatomic) unsigned int m_uiChatRoomMaxCount; // @synthesize m_uiChatRoomMaxCount;
@property(nonatomic) unsigned int m_uiChatRoomVersion; // @synthesize m_uiChatRoomVersion;
@property(retain, nonatomic) NSString *m_nsEncodeUserName; // @synthesize m_nsEncodeUserName;
@property(retain, nonatomic) NSString *m_nsAliasName; // @synthesize m_nsAliasName;
@property(retain, nonatomic) NSString *m_nsCardUrl; // @synthesize m_nsCardUrl;
@property(retain, nonatomic) NSString *m_nsDescriptionPY; // @synthesize m_nsDescriptionPY;
@property(retain, nonatomic) NSString *m_nsDescription; // @synthesize m_nsDescription;
@property(retain, nonatomic) NSString *m_nsTagList; // @synthesize m_nsTagList;
@property(nonatomic) unsigned int m_uiUpdateTime; // @synthesize m_uiUpdateTime;
@property(nonatomic) unsigned int m_uiDraftTime; // @synthesize m_uiDraftTime;
@property(nonatomic) BOOL m_isShowRedDot; // @synthesize m_isShowRedDot;
@property(copy, nonatomic) NSString *m_nsChatRoomData; // @synthesize m_nsChatRoomData;
//@property(retain, nonatomic) SubscriptBrandInfo *m_subBrandInfo; // @synthesize m_subBrandInfo;
@property(nonatomic) unsigned int m_uiBrandSubscriptionSettings; // @synthesize m_uiBrandSubscriptionSettings;
@property(copy, nonatomic) NSString *m_nsBrandSubscriptConfigUrl; // @synthesize m_nsBrandSubscriptConfigUrl;
@property(copy, nonatomic) NSString *m_nsExternalInfo; // @synthesize m_nsExternalInfo;
@property(retain, nonatomic) NSString *m_pcWCBGImgID; // @synthesize m_pcWCBGImgID;
@property(nonatomic) unsigned int m_uiWCFlag; // @synthesize m_uiWCFlag;
@property(copy, nonatomic) NSString *m_nsWCBGImgObjectID; // @synthesize m_nsWCBGImgObjectID;
@property(nonatomic) unsigned int m_uiNeedUpdate; // @synthesize m_uiNeedUpdate;
@property(copy, nonatomic) NSString *m_nsOwner; // @synthesize m_nsOwner;
@property(nonatomic) unsigned int m_uiWeiboFlag; // @synthesize m_uiWeiboFlag;
@property(copy, nonatomic) NSString *m_nsWeiboNickName; // @synthesize m_nsWeiboNickName;
@property(copy, nonatomic) NSString *m_nsWeiboAddress; // @synthesize m_nsWeiboAddress;
@property(nonatomic) unsigned int m_uiFriendScene; // @synthesize m_uiFriendScene;
@property(retain, nonatomic) NSString *m_nsCertificationInfo; // @synthesize m_nsCertificationInfo;
@property(copy, nonatomic) NSString *m_nsHDImgStatus; // @synthesize m_nsHDImgStatus;
@property(copy, nonatomic) NSString *m_nsSignature; // @synthesize m_nsSignature;
@property(copy, nonatomic) NSString *m_nsCity; // @synthesize m_nsCity;
@property(copy, nonatomic) NSString *m_nsProvince; // @synthesize m_nsProvince;
@property(copy, nonatomic) NSString *m_nsCountry; // @synthesize m_nsCountry;
@property(retain, nonatomic) NSString *m_nsQQRemark; // @synthesize m_nsQQRemark;
@property(retain, nonatomic) NSString *m_nsQQNickName; // @synthesize m_nsQQNickName;
@property(nonatomic) unsigned int m_uiQQUin; // @synthesize m_uiQQUin;
@property(retain, nonatomic) NSString *m_nsMobileIdentify; // @synthesize m_nsMobileIdentify;
@property(nonatomic) unsigned int m_uiImgKeyAtLastGet; // @synthesize m_uiImgKeyAtLastGet;
@property(nonatomic) unsigned int m_uiExtKey; // @synthesize m_uiExtKey;
@property(nonatomic) unsigned int m_uiChatState; // @synthesize m_uiChatState;
@property(retain, nonatomic) NSString *m_nsGoogleContactName; // @synthesize m_nsGoogleContactName;
@property(retain, nonatomic) NSString *m_nsBrandIconUrl; // @synthesize m_nsBrandIconUrl;
@property(retain, nonatomic) NSString *m_nsDraft; // @synthesize m_nsDraft;
@property(nonatomic) unsigned int m_uiChatRoomStatus; // @synthesize m_uiChatRoomStatus;
@property(retain, nonatomic) NSString *m_nsChatRoomMemList; // @synthesize m_nsChatRoomMemList;
@property(retain, nonatomic) NSString *m_nsHeadHDMd5; // @synthesize m_nsHeadHDMd5;
@property(nonatomic) unsigned int m_uiImgKey; // @synthesize m_uiImgKey;
@property(retain, nonatomic) NSString *m_nsImgStatus; // @synthesize m_nsImgStatus;
@property(nonatomic) unsigned int m_uiType; // @synthesize m_uiType;
@property(nonatomic) unsigned int m_uiSex; // @synthesize m_uiSex;
@property(nonatomic) unsigned int m_uiCertificationFlag; // @synthesize m_uiCertificationFlag;
@property(retain, nonatomic) NSString *m_nsRemarkPYShort; // @synthesize m_nsRemarkPYShort;
@property(retain, nonatomic) NSString *m_nsRemarkPYFull; // @synthesize m_nsRemarkPYFull;
@property(retain, nonatomic) NSString *m_nsShortPY; // @synthesize m_nsShortPY;
@property(retain, nonatomic) NSString *m_nsFullPY; // @synthesize m_nsFullPY;
@property(nonatomic) unsigned int m_uiConType; // @synthesize m_uiConType;

@property(readonly, nonatomic) NSArray *m_nsTagListArray;

@property(readonly, nonatomic) unsigned long long groupMemberCount;


@property(retain, nonatomic) NSString *m_nsNickName; // @synthesize m_nsNickName;
@property(retain, nonatomic) NSString *m_nsUsrName; // @synthesize m_nsUsrName;
@property(retain, nonatomic) NSString *m_nsRemark; // @synthesize m_nsRemark;
@property(retain, nonatomic) NSString *m_nsHeadHDImgUrl; // @synthesize m_nsHeadHDImgUrl;
@property(retain, nonatomic) NSString *m_nsHeadImgUrl; // @synthesize m_nsHeadImgUrl;
@property(retain, nonatomic) NSString *m_nsGroupDisplayName; // @synthesize m_nsHeadImgUrl;

//获取群内昵称方法
- (id)groupChatNickNameInGroup:(id)arg1;
- (id)groupChatDisplayNameInGroup:(id)arg1;


@end
