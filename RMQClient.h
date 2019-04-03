//
//  RMQClient.h
//  WechatPluginPro
//
//  Created by dcd on 2017/12/18.
//  Copyright © 2017年 刘伟. All rights reserved.
//

#ifndef RMQClient_h
#define RMQClient_h

#import <AppKit/AppKit.h>
#import "RMQConnection.h"
#import "RMQErrors.h"
#import "RMQBasicProperties.h"
#import "RMQBasicProperties+MergeDefaults.h"
#import "RMQFrame.h"
#import "RMQHeartbeat.h"
#import "RMQMethodDecoder.h"
#import "RMQMethodMap.h"
#import "RMQMethods+Convenience.h"
#import "RMQProtocolHeader.h"
#import "RMQURI.h"
#import "RMQAllocatedChannel.h"
#import "RMQConnectionDelegateLogger.h"
#import "RMQConnectionRecover.h"
#import "RMQSuspendResumeDispatcher.h"
#import "RMQFramesetValidator.h"
#import "RMQHandshaker.h"
#import "RMQMultipleChannelAllocator.h"
#import "RMQReader.h"
#import "RMQSynchronizedMutableDictionary.h"
#import "RMQTCPSocketTransport.h"
#import "RMQUnallocatedChannel.h"
#import "RMQGCDSerialQueue.h"
#import "RMQSemaphoreWaiterFactory.h"
#import "RMQSemaphoreWaiter.h"
#import "RMQProcessInfoNameGenerator.h"
#import "RMQQueuingConnectionDelegateProxy.h"
#import "RMQGCDHeartbeatSender.h"
#import "RMQTickingClock.h"
#import "RMQPKCS12CertificateConverter.h"
#import "RMQTLSOptions.h"
#import "RMQTransactionalConfirmations.h"
#import "RMQConfirmationTransaction.h"

//! Project version number for RMQClient.
FOUNDATION_EXPORT double RMQClientVersionNumber;

//! Project version string for RMQClient.
FOUNDATION_EXPORT const unsigned char RMQClientVersionString[];

#endif /* RMQClient_h */
