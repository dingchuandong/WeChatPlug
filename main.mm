//
//  main.c
//  WechatPluginPro
//
//  Created by 刘伟 on 2017/11/30.
//  Copyright © 2017年 刘伟. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+hookWechat.h"

static void __attribute__((constructor))initialize(void){

    [NSObject readConfig];

}

