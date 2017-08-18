//
//  VideoCapture.m
//  LGLiveApp
//
//  Created by weiguang on 2017/8/2.
//  Copyright © 2017年 weiguang. All rights reserved.
//

#import "VideoCapture.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "H264Encoder.h"

@interface VideoCapture()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic,strong) AVCaptureSession *captureSession;
@property (nonatomic,strong) AVCaptureVideoPreviewLayer *preViewlayer;
@property (nonatomic,strong) H264Encoder *encoder;
@property (nonatomic,strong) AVCaptureDevice *videoDevice;
@property (nonatomic,strong) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic,strong) AVCaptureConnection *connection;
@property (nonatomic,strong) AVCaptureVideoDataOutput *videoOutput;

@end

@implementation VideoCapture
{
    dispatch_queue_t mEncodeQueue;
}

- (void)startCapturing:(UIView *)preview{
    
    /* ======================编码准备============================*/
    self.encoder = [[H264Encoder alloc] init];
    
    mEncodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_sync(mEncodeQueue, ^{
        [self.encoder prepareEncodeWithWidth:720 height:1280];
    });
    
    /* ======================视频采集============================*/
    //1.创建会话
    AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
    captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    self.captureSession = captureSession;
    
    //2.设置视频的输入
    // 2.1获取输入设备，摄像头,默认为后置
    self.videoDevice = [self getVideoDevice:AVCaptureDevicePositionBack];
    
    //2.2创建对应视频输入对象
    self.videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.videoDevice error:nil];
    
    //2.3添加到会话中
    // 注意：最好要判断是否能添加输入，会话不能添加空的
    if ([captureSession canAddInput:_videoDeviceInput]) {
         [captureSession addInput:_videoDeviceInput];
    }
   
    // 3.设置视频输出
    // 3.1获取视频输出设备
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    //默认为YES，接收器会立即丢弃接收到的帧，在代理里面，NO的时候，将允许在丢弃之前有更多时间处理旧帧
   // [videoOutput setAlwaysDiscardsLateVideoFrames:NO];
    // 3.2 设置输出代理，捕获视频样品数据
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    [_videoOutput setSampleBufferDelegate:self queue:queue];
    if ([captureSession canAddOutput:_videoOutput]) {
        [captureSession addOutput:_videoOutput];
    }
    
    //3.3 设置视频输出方向
    // 注意：设置方向，必须在videoOutput添加到captureSession之后，否则出错
    self.connection = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
    if (_connection.isVideoOrientationSupported) {
        [_connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    }
    
    // 4. 添加视频预览层
    AVCaptureVideoPreviewLayer *layer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    self.preViewlayer = layer;
    [layer setVideoGravity:AVLayerVideoGravityResizeAspect];//默认就是此值
    layer.frame = preview.bounds;
    [preview.layer insertSublayer:layer atIndex:0];
    
    // 5.开始采集
    [captureSession startRunning];
    
}

- (void)stopCapturing{
    [self.captureSession stopRunning];
    [self.preViewlayer removeFromSuperlayer];
    [self.encoder endEncode];
}

//指定摄像头方向，获取摄像头,默认为后置
- (AVCaptureDevice *)getVideoDevice:(AVCaptureDevicePosition)position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

// 切换采集摄像头
- (void)switchScene:(UIView *)preview{
    // 1.添加动画
    CATransition *rotaionAnim = [[CATransition alloc] init];
    rotaionAnim.type = @"oglFlip";
    rotaionAnim.subtype = @"fromLeft";
    rotaionAnim.duration = 0.5;
    [preview.layer addAnimation:rotaionAnim forKey:nil];
    
    // 2.获取当前镜头
    AVCaptureDevicePosition position = self.videoDeviceInput.device.position == AVCaptureDevicePositionBack ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
    
    // 3.创建新的input对象
    AVCaptureDevice *newDevice = [self getVideoDevice:position];
    AVCaptureDeviceInput *newDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:newDevice error:nil];
    
    // 4.移除旧输入，添加新输入
    [self.captureSession beginConfiguration];
    [self.captureSession removeInput:self.videoDeviceInput];
    [self.captureSession addInput:newDeviceInput];
    // 此处要重新设置视频输出方向，默认会旋转90度
    self.connection = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
    if (_connection.isVideoOrientationSupported) {
        [_connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    }

    [self.captureSession commitConfiguration];
    // 5.保存新输入
    self.videoDeviceInput = newDeviceInput;
}

#pragma mark -- 代理
//丢帧的时候调用，一般不用
- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{

}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    NSLog(@"获取到一帧数据");
    dispatch_sync(mEncodeQueue, ^{
        // 对获取到的数据进行编码
        [self.encoder encodeFrame:sampleBuffer];
    });
}



@end
