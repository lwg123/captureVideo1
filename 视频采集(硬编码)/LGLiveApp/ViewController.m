//
//  ViewController.m
//  LGLiveApp
//
//  Created by weiguang on 2017/8/2.
//  Copyright © 2017年 weiguang. All rights reserved.
//

#import "ViewController.h"
#import "VideoCapture.h"


@interface ViewController ()

@property (nonatomic,strong) VideoCapture *videoCapture;


@end

@implementation ViewController

- (VideoCapture *)videoCapture{
    if (!_videoCapture) {
        _videoCapture = [[VideoCapture alloc] init];
    }
    return _videoCapture;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}
- (IBAction)startCpture:(UIButton *)sender {
    if (sender.tag == 1) {
        NSLog(@"开始采集");
        
        [self.videoCapture startCapturing:self.view];
       
    }else if (sender.tag == 2){
        NSLog(@"停止采集");
        [self.videoCapture stopCapturing];
    }else{
        NSLog(@"default....");
    }
}
- (IBAction)switchInputDevice:(UIButton *)sender {
    
    [self.videoCapture switchScene:self.view];
}




@end
