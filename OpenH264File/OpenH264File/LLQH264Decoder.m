//
//  LLQH264Decoder.m
//  OpenH264File
//
//  Created by LLQ on 16/12/6.
//  Copyright © 2016年 LLQ. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LLQH264Decoder.h"
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>

@interface LLQH264Decoder()<UIAlertViewDelegate>
{
    AVFormatContext *pFormatCtx;
    int i,videoIndex;
    AVCodecContext *pCodecCtx;
    AVCodec *pCodec;
    AVFrame *pFrame, *pFrameYUV;
    uint8_t *out_Buffer;
    AVPacket *packet;
    int ret,got_picture;
    struct SwsContext *img_convert_ctx;
    int frame_cnt;
}
@property(nonatomic, copy)NSString *filePath;

@end
@implementation LLQH264Decoder

- (instancetype)initWithH264FilePath:(NSString *)h264FilePath{
    
    self = [super init];
    if (self) {
        self.filePath = h264FilePath;
    }
    
    return self;
}

- (void)startDecoder{
    
    [self setupFFMPEGwithPath:self.filePath];
    
}

- (void)setupFFMPEGwithPath:(NSString *)path{
    
    //注册编解码器
    av_register_all();
    //
    avformat_network_init();
    //初始化
    pFormatCtx = avformat_alloc_context();
    
    //打开文件  返回0表示成功，所有数据存储在formatCtx中
    if (avformat_open_input(&pFormatCtx, path.UTF8String, NULL, NULL) != 0) {
        [self showAlerViewTitle:@"不能打开流文件"];
        return;
    }
    
    //读取数据包获取流媒体文件的信息
    if (avformat_find_stream_info(pFormatCtx, NULL) < 0) {
        [self showAlerViewTitle:@"不能读取到流信息"];
        return;
    }
    
    videoIndex = -1;
    //查找视频流
    //nb_streams视音频流的个数
    //streams视音频流
    for (i = 0; i < pFormatCtx->nb_streams; i ++) {
        //直至查找到视频流
        if (pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoIndex = i;
            NSLog(@"videoIndex==%d",videoIndex);  //视频流的下标
            break;
        }
        if (videoIndex == -1) {
            [self showAlerViewTitle:@"没有视频流"];
            return;
        }
    }
    
    //取出查找到的视频流的解码器信息
    pCodecCtx = pFormatCtx->streams[videoIndex]->codec;
    
    //初始化解码器
    pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
    
    if (pCodec == NULL) {
        [self showAlerViewTitle:@"找不到解码器"];
        return;
    }
    
    //打开解码器
    if (avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
        [self showAlerViewTitle:@"不能打开解码器"];
        return;
    }
    
    //初始化frame，packet
    //AVPacket里面的是H.264码流数据
    //AVFrame里面装的是YUV数据。YUV是经过decoder解码AVPacket的数据
    pFrame = av_frame_alloc();
    packet = (AVPacket *)malloc(sizeof(AVPacket));
    
    //打印一大堆时间、比特率,流,容器,编解码器和时间等
    av_dump_format(pFormatCtx, 0, path.UTF8String, 0);
    
    //
    img_convert_ctx = sws_getContext(pCodecCtx->width, pCodecCtx->height, pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height, PIX_FMT_YUV420P, SWS_BICUBIC, NULL, NULL, NULL);
    frame_cnt = 0;
    
    //开辟线程操作
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //从formatCtx中读取
        while (av_read_frame(pFormatCtx, packet) >= 0) {
            NSLog(@"packet->data==%d",packet->size);
            if (packet->stream_index == videoIndex) {
                //根据获取到的packet生成pFrame(AVFrame)实际上就是解码
                //如果没有需要解码的帧则got_picture就会为0
                ret = avcodec_decode_video2(pCodecCtx, pFrame, &got_picture, packet);
                if (ret < 0) {
                    [self showAlerViewTitle:@"解码错误"];
                    return;
                }
                if (got_picture) {
                    
                    //OpenGL GPU渲染
                    [self makeYUVframe];
                    
                    //imageView播放
//                    [self makeImage];
                    
                }
            }
            av_free_packet(packet);
        }
        
        sws_freeContext(img_convert_ctx);
        av_frame_free(&pFrameYUV);
        av_frame_free(&pFrame);
        avcodec_close(pCodecCtx);
        avformat_close_input(&pFormatCtx);
        [[NSNotificationCenter defaultCenter] postNotificationName:decodeDidFinishNotification object:nil];
    });
    
}

//YUV转RGB
- (void)makeYUVframe{
    
    unsigned int lumaLength = (pCodecCtx->height)*(MIN(pFrame->linesize[0], pCodecCtx->width));
    unsigned int chromBLength = ((pCodecCtx->height)/2)*(MIN(pFrame->linesize[1], (pCodecCtx->width)/2));
    unsigned int chromRLength = ((pCodecCtx->height)/2)*(MIN(pFrame->linesize[1], (pCodecCtx->width)/2));
    
    //初始化
    H264YUV_Frame yuvFrame;
    
    memset(&yuvFrame, 0, sizeof(H264YUV_Frame));
    
    yuvFrame.luma.length = lumaLength;
    yuvFrame.chromaB.length = chromBLength;
    yuvFrame.chromaR.length = chromRLength;
    
    yuvFrame.luma.dataBuffer = (unsigned char*)malloc(lumaLength);
    yuvFrame.chromaB.dataBuffer = (unsigned char*)malloc(chromBLength);
    yuvFrame.chromaR.dataBuffer = (unsigned char*)malloc(chromRLength);
    
    //转RGB
    copyDecodedFrame(pFrame->data[0], yuvFrame.luma.dataBuffer, pFrame->linesize[0], pCodecCtx->width, pCodecCtx->height);
    copyDecodedFrame(pFrame->data[1], yuvFrame.chromaB.dataBuffer, pFrame->linesize[1], pCodecCtx->width/2, pCodecCtx->height/2);
    copyDecodedFrame(pFrame->data[2], yuvFrame.chromaR.dataBuffer, pFrame->linesize[2], pCodecCtx->width/2, pCodecCtx->height/2);
    
    yuvFrame.width = pCodecCtx->width;
    yuvFrame.height = pCodecCtx->height;
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        
        if([self.delegate respondsToSelector:@selector(updateYUVFrameOnMainThread:)]){
            [self.delegate updateYUVFrameOnMainThread:(H264YUV_Frame *)&yuvFrame];
        }
        
    });
    
    free(yuvFrame.luma.dataBuffer);
    free(yuvFrame.chromaB.dataBuffer);
    free(yuvFrame.chromaR.dataBuffer);
    
}

//转RGB算法
void copyDecodedFrame(unsigned char *src, unsigned char *dist,int linesize, int width, int height)
{
    
    width = MIN(linesize, width);
    
    for (NSUInteger i = 0; i < height; ++i) {
        memcpy(dist, src, width);
        dist += width;
        src += linesize;
    }
    
}

//转为image
- (void)makeImage{
    
    //给picture分配空间
    AVPicture pictureL = [self AllocAVPicture];
    int pictRet = sws_scale (img_convert_ctx,(const uint8_t * const *)pFrame->data, pFrame->linesize,
                             0, pCodecCtx->height,
                             pictureL.data, pictureL.linesize);
    if (pictRet > 0) {
        UIImage * image = [self imageFromAVPicture:pictureL width:pCodecCtx->width height:pCodecCtx->height];
        [NSThread sleepForTimeInterval:1.0/80.0];
        if ([self.delegate respondsToSelector:@selector(updateImageOnMainTread:)]) {
            [self.delegate updateImageOnMainTread:image];
        }
        
    }
    //释放AVPicture
    avpicture_free(&pictureL);
    
}

-(AVPicture)AllocAVPicture
{
    //创建AVPicture
    AVPicture pictureL;
    sws_freeContext(img_convert_ctx);
    avpicture_alloc(&pictureL, PIX_FMT_RGB24,pCodecCtx->width,pCodecCtx->height);
    static int sws_flags =  SWS_FAST_BILINEAR;
    img_convert_ctx = sws_getContext(pCodecCtx->width,
                                     pCodecCtx->height,
                                     pCodecCtx->pix_fmt,
                                     pCodecCtx->width,
                                     pCodecCtx->height,
                                     PIX_FMT_RGB24,
                                     sws_flags, NULL, NULL, NULL);
    
    
    return pictureL;
}

/**AVPicture转UIImage*/
-(UIImage *)imageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height {
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, pict.data[0], pict.linesize[0]*height,kCFAllocatorNull);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(width,
                                       height,
                                       8,
                                       24,
                                       pict.linesize[0],
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CFRelease(data);
    
    return image;
}


#pragma mark ------ UIAlertViewDelegate

-(void)showAlerViewTitle:(NSString*)title
{
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:title message:nil delegate:self cancelButtonTitle:@"取消" otherButtonTitles:nil, nil];
    [alert show];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSLog(@"取消");
    switch (buttonIndex) {
        case 0:{
            [[NSNotificationCenter defaultCenter] postNotificationName:decodeFailureNotification object:nil];
        }
            break;
            
        default:
            break;
    }
}

@end
