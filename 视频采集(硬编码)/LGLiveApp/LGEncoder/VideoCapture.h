//
//  VideoCapture.h
//  LGLiveApp
//
//  Created by weiguang on 2017/8/2.
//  Copyright © 2017年 weiguang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VideoCapture : NSObject

- (void)startCapturing:(UIView *)preview;

- (void)stopCapturing;

// 切换场景
- (void)switchScene:(UIView *)preview;

@end
