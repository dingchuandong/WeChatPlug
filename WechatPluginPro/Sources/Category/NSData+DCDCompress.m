//
//  NSData+DCDCompress.m
//  WechatPluginPro
//
//  Created by boohee on 2018/7/3.
//  Copyright © 2018年 boohee. All rights reserved.
//

#import "NSData+DCDCompress.h"

@implementation NSData (DCDCompress)

- (NSData *)compressImageData:(NSData *)originImageData toKb:(NSInteger)kb;
{
    if (!originImageData) {
        return nil;
    }
    kb*=1024;
    CGFloat compression = 0.9f;
    CGFloat maxCompression = 0.1f;
    while ([originImageData length] > kb && compression > maxCompression) {
        compression -= 0.2;
        NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:originImageData];
        //图片质量
        NSNumber *quality = [NSNumber numberWithFloat:compression];
        NSDictionary *imageProps = [NSDictionary dictionaryWithObject:quality forKey:NSImageCompressionFactor];
        originImageData = [imageRep representationUsingType:NSJPEGFileType properties:imageProps];
    }
    DDLogDebug(@"当前大小:%fkb",(float)[originImageData length]/1024.0f);
    return originImageData;
}
@end
