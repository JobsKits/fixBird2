//
//  JobsDebugDeinitAutoLoad.m
//  Pods
//
//  Created by Jobs on 2026年6月24日，星期三.
//

@import Foundation;
@import UIKit;
@import JobsSwiftDebugTools;
/// 将此文件集成到主工程
@interface JobsDebugDeinitAutoLoad : NSObject

@end

@implementation JobsDebugDeinitAutoLoad

+ (void)load {
#if DEBUG
    [JobsDebugDeinitAutoSwizzle start];
#endif
}

@end
