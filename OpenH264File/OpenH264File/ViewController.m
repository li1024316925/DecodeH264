//
//  ViewController.m
//  OpenH264File
//
//  Created by LLQ on 16/12/6.
//  Copyright © 2016年 LLQ. All rights reserved.
//

#import "ViewController.h"
#import "OpenGLFrameView.h"
#import "LLQH264Decoder.h"

@interface ViewController ()<OpenGLESViewPTZDelegate,LLQH264DecoderDelegate>
{
    OpenGLFrameView *_openGLFrameView;
    LLQH264Decoder *_decoder;
}
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    OpenGLFrameView *openGLframeView = [[OpenGLFrameView alloc] initWithFrame:CGRectMake(0, 100, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.width * (9.0 /16.0))];
    openGLframeView.openGLESViewPTZDelegate = self;
    [self.view addSubview:openGLframeView];
    _openGLFrameView = openGLframeView;
    
    //创建解码器
    NSString * videoPath =[[NSBundle mainBundle] pathForResource:@"SPSTest.h264" ofType:nil];
    LLQH264Decoder *decoder = [[LLQH264Decoder alloc] initWithH264FilePath:videoPath];
    decoder.delegate = self;
    _decoder = decoder;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(decodeFailure:) name:decodeFailureNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(decodeDidFinish:) name:decodeDidFinishNotification object:nil];
    
}

- (IBAction)playAction:(UIButton *)sender {
    if (sender.selected == YES) return;
    sender.selected = !sender.selected;
    [_decoder startDecoder];
}

-(void)decodeFailure:(NSNotification *)info
{
    self.startButton.selected = NO;
}

-(void)decodeDidFinish:(NSNotification *)info
{
    self.startButton.selected = NO;
}

#pragma mark ------ LLQH264DecoderDelegate

- (void)updateYUVFrameOnMainThread:(H264YUV_Frame *)yuvFrame{
    
    [_openGLFrameView render:yuvFrame];
    
}

- (void)updateImageOnMainTread:(UIImage *)image{
    
    dispatch_sync(dispatch_get_main_queue(), ^{
       
        _imageView.image = image;
        
    });
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
