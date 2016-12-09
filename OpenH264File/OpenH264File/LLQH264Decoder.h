//
//  LLQH264Decoder.h
//  OpenH264File
//
//  Created by LLQ on 16/12/6.
//  Copyright © 2016年 LLQ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DecodeH264Data_YUV.h"

#define decodeDidFinishNotification @"decodeDidFinishNotification"
#define decodeFailureNotification @"decodeFailureNotification"

@protocol LLQH264DecoderDelegate <NSObject>

@optional

//RGB数据
- (void)updateYUVFrameOnMainThread:(H264YUV_Frame *)yuvFrame;

//Image数据
- (void)updateImageOnMainTread:(UIImage *)image;

@end




@interface LLQH264Decoder : NSObject

@property (nonatomic, assign)id<LLQH264DecoderDelegate> delegate;

- (instancetype)initWithH264FilePath:(NSString *)h264FilePath;
- (void)startDecoder;

@end
