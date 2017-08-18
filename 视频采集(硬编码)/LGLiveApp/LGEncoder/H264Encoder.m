//
//  H264Encoder.m
//  LGLiveApp
//
//  Created by weiguang on 2017/8/2.
//  Copyright © 2017年 weiguang. All rights reserved.
//

#import "H264Encoder.h"

@implementation H264Encoder
{
    VTCompressionSessionRef compressionSession;
    int frameID;
    NSFileHandle *fileHandle;
}

- (void)prepareEncodeWithWidth:(int)width height:(int)height{
    frameID = 0;
    // 创建fileHandle
    NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"abc.h264"];
    
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
    // 必须先创建文件，fileHandle才有值
    fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    
    
    // 1.创建VTCompressionSessionRef
    /*
     *参数解析
     参数一： CFAllocatorRef CoreFoundation内存分配模式，NULL为默认的分配方式
     参数二：编码出来视频的宽度
     参数三：编码出来视频的高度
     参数四：编码标准：H.264/AVC
     
     参数五/六/七 一般NULL
     参数八：VTCompressionOutputCallback，编码完成后的回调函数
     
     @param	outputCallback
     The callback to be called with compressed frames.
     This function may be called asynchronously, on a different thread from the one that calls VTCompressionSessionEncodeFrame.
     
     参数九：
     @param	outputCallbackRefCon
     Client-defined reference value for the output callback.
     一般传self
     参数十：
     传一个新的 VTCompressionSessionRef类型指针
     */
    VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressionCallback, (__bridge void * _Nullable)(self), &compressionSession);
    
    // 2.设置属性
     // 2.1 设置实时编码输出
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    
    // 2.2 设置期望帧率
//    int fps = 24;
//    CFNumberRef fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
    //此处第三个参数，可以设置为fpsRef，或者直接通过桥接转换
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef _Nonnull)(@24));
    // 2.3 设置比特率(码率) 1500000/s ,单位是bps
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef _Nonnull)(@1500000));
    //设置码率，上限，单位是byte
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFTypeRef _Nonnull)(@[@(1500000/8), @1]));
    // 2.4 设置关键帧（GOPsize)间隔
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef _Nonnull)(@20));
    // 3.准备编码
    VTCompressionSessionPrepareToEncodeFrames(compressionSession);
}

- (void)encodeFrame:(CMSampleBufferRef)sampleBuffer{
    // 1. 将CMSampleBufferRef转化为CVImageBufferRef
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // 2. 设置帧时间
    CMTime presentationTimeStamp = CMTimeMake(frameID++, 100);
    // 第七个参数，这个参数也可以传NULL，也可以传&infoFlagsOut
   // VTEncodeInfoFlags infoFlagsOut;
    OSStatus statusCode = VTCompressionSessionEncodeFrame(compressionSession, imageBuffer, presentationTimeStamp, kCMTimeInvalid, NULL, NULL,NULL);
    //编码失败
    if (statusCode != noErr) {
        NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
        VTCompressionSessionInvalidate(compressionSession);
        CFRelease(compressionSession);
        compressionSession = NULL;
        return;
    }
    
     NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
}

void didCompressionCallback(
                        void * outputCallbackRefCon,
                        void * sourceFrameRefCon,
                        OSStatus status,
                        VTEncodeInfoFlags infoFlags,
                        CMSampleBufferRef sampleBuffer ){
    
    H264Encoder *encoder = (__bridge H264Encoder *)(outputCallbackRefCon);
    
    //1.判断该帧是否为关键帧
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    CFDictionaryRef dict = CFArrayGetValueAtIndex(attachments, 0);
    BOOL isKeyFrame = !CFDictionaryContainsKey(dict, kCMSampleAttachmentKey_NotSync);
    
    //2.如果是关键帧，获取SPS/PPS数据，并且写入文件
    if (isKeyFrame) {
        //2.1 获取编码后的信息（存储于CMFormatDescriptionRef中）
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        //2.2 获取SPS信息
        const uint8_t *spsOut;
        size_t spsSize, spsCount;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &spsOut, &spsSize, &spsCount, NULL);
        
        //2.3 获取PPS信息
        const uint8_t *ppsOut;
        size_t ppsSize, ppsCount;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &ppsOut, &ppsSize, &ppsCount, NULL);
        
        // 2.4 将PPS、SPS转成NSData，并且写入文件
        NSData *spsData = [NSData dataWithBytes:spsOut length:spsSize];
        NSData *ppsData = [NSData dataWithBytes:ppsOut length:ppsSize];
        
        //2.5 写入文件
        [encoder writeToData:spsData];
        [encoder writeToData:ppsData];
        
    }
    
    //3. 获取编码后的数据，写入文件
    // 3.1 获取CMBlockBufferRef
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    
    // 3.2 从CMBlockBufferRef中获取起始位置的内存地址
    size_t totalLength = 0;
    char *dataPointer;
    CMBlockBufferGetDataPointer(dataBuffer, 0, NULL, &totalLength, &dataPointer);
    
    // 3.3 一帧的图像可能需要写入多个NALU单元 --Slice切片
    static const int H264HeaderLength = 4; // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
    size_t bufferOffset = 0;
    
    //循环获取NALU数据
    while (bufferOffset < totalLength - H264HeaderLength) {
        // 3.4 从起始位置拷贝H264HeaderLength长度的地址，计算NALULength
        uint32_t NALULength = 0;
        // Read the NAL unit length
        memcpy(&NALULength, dataPointer + bufferOffset, H264HeaderLength);
        
        // 大端/小端模式 --> 系统模式
        // H264编码的数据是大端模式（字节序）
        NALULength = CFSwapInt32BigToHost(NALULength);
        
        // 3.5 从dataPointer开始，根据长度创建NSData
        NSData *data = [NSData dataWithBytes:(dataPointer + bufferOffset + H264HeaderLength) length:NALULength];
        
        // 3.6 写入文件
        [encoder writeToData:data];
        // 3.7 重新设置bufferOffset
        // 移动到写一个块，转成NALU单元
        bufferOffset += NALULength + H264HeaderLength;
        
    }
    
}

- (void)writeToData:(NSData *)data{
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = sizeof(bytes) - 1;  //c语言字符串末尾默认有一个'\0'，否则取出来的长度多一位
    NSData *headerData = [NSData dataWithBytes:bytes length:length];
    [fileHandle writeData:headerData];
    [fileHandle writeData:data];
    
}

- (void)endEncode
{
    VTCompressionSessionCompleteFrames(compressionSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(compressionSession);
    CFRelease(compressionSession);
    compressionSession = NULL;
    [fileHandle closeFile];
    fileHandle = NULL;
}



@end
