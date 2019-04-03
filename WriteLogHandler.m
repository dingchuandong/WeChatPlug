//
//  WriteLogHandler.m
//  WechatPluginPro
//
//  Created by dcd on 2018/1/11.
//  Copyright © 2018年 刘伟. All rights reserved.
//

#import "WriteLogHandler.h"
#import "UserInfo.h"

@implementation WriteLogHandler

+ (WriteLogHandler *)shareLogHander;
{
    static WriteLogHandler* shareLogHander = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareLogHander = [[self alloc] init];
        //
    });
    return shareLogHander;
}


- (void)writefile:(NSString *)infoStr
{
    if (![UserInfo shareUserInfo].userName) {
        return;
    }
    NSArray *paths  = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *homePath = [paths objectAtIndex:0];
    NSString *logPath = [homePath stringByAppendingPathComponent:@"Log"];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *datestr = [dateFormatter stringFromDate:[NSDate date]];
    NSString *yearStr = [datestr componentsSeparatedByString:@" "][0];
    
    NSString *fileName = [NSString stringWithFormat:@"%@%@.log",yearStr,[UserInfo shareUserInfo].userName];
    NSString *filePath = [logPath stringByAppendingPathComponent:fileName];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:logPath]) {
        //创建文件夹
        [fileManager createDirectoryAtPath:logPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if(![fileManager fileExistsAtPath:filePath]) //如果不存在
    {
        NSString *str = @"😆😆😆😆😆冰山项目日志😆😆😆😆😆\n";
        //创建文件
        [str writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
    [fileHandle seekToEndOfFile];  //将节点跳到文件的末尾

    NSString *str = [NSString stringWithFormat:@"\n\n%@\n===事件===\n%@\n===事件===",datestr,infoStr];
    NSData* stringData  = [str dataUsingEncoding:NSUTF8StringEncoding];
    [fileHandle writeData:stringData]; //追加写入数据
    [fileHandle closeFile];
}

@end
