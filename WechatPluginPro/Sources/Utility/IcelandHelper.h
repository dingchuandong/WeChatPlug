//
//  SkingHelper.h
//  WechatPluginPro
//
//  Created by 刘伟 on 2017/12/4.
//  Copyright © 2017年 boohee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface IcelandHelper : NSObject

/**
 替换对象方法
 
 @param originalClass 原始类
 @param originalSelector 原始类的方法
 @param swizzledClass 替换类
 @param swizzledSelector 替换类的方法
 */
void icelandHookMethod(Class originalClass, SEL originalSelector, Class swizzledClass, SEL swizzledSelector);

/**
 替换类方法
 
 @param originalClass 原始类
 @param originalSelector 原始类的类方法
 @param swizzledClass 替换类
 @param swizzledSelector 替换类的类方法
 */
void icelandHookClassMethod(Class originalClass, SEL originalSelector, Class swizzledClass, SEL swizzledSelector);

@end
