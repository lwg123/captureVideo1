//
//  H264Encoder.h
//  LGLiveApp
//
//  Created by weiguang on 2017/8/2.
//  Copyright © 2017年 weiguang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface H264Encoder : NSObject

- (void)prepareEncodeWithWidth:(int)width height:(int)height;

- (void)encodeFrame:(CMSampleBufferRef)sampleBuffer;

- (void)endEncode;

@end
