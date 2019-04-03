//
//  NSData+DCDCompress.h
//  WechatPluginPro
//
//  Created by boohee on 2018/7/3.
//  Copyright © 2018年 boohee. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (DCDCompress)

- (NSData *)compressImageData:(NSData *)originImageData toKb:(NSInteger)kb;

@end
