//
//  ViewController.m
//  VoiceMessage
//
//  Created by 李伟宾 on 2017/11/28.
//  Copyright © 2017年 liweibin. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()
{
    UIButton        *_recordButton;     //开始录音
    UIButton        *_playRecordButton; //播放录音
    
    UIView          *_volumeBgView;     //音量背景视图
    UIImageView     *_volumeImageView;  //音量图片
    UILabel         *_volumeLabel;      //提示文字
    
    NSTimer         *_timer;            //定时器
    NSInteger       _countDown;         //倒计时,最多60秒
    
    AVAudioSession      *_session;
    AVAudioRecorder     *_recorder;    //录音器
    AVAudioPlayer       *_player;      //音频播放器
    NSString            *_recordFilePath;     //录音文件沙盒地址
    
    BOOL _isLeaveSpeakBtn;   //是否上滑
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];
    
    _recordButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _recordButton.frame = CGRectMake(50 , 100, 300 , 50);
    [_recordButton setImage:[UIImage imageNamed:@"press_for_audio"] forState:UIControlStateNormal];
    [_recordButton setImage:[UIImage imageNamed:@"press_for_audio_down"] forState:UIControlStateHighlighted];
    [_recordButton addTarget:self action:@selector(recordButtonTouchDown) forControlEvents:UIControlEventTouchDown];
    [_recordButton addTarget:self action:@selector(recordButtonTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
    [_recordButton addTarget:self action:@selector(recordButtonTouchUpOutside) forControlEvents:UIControlEventTouchUpOutside];
    [_recordButton addTarget:self action:@selector(recordButtonTouchUpDragExit) forControlEvents:UIControlEventTouchDragExit];
    [_recordButton addTarget:self action:@selector(recordButtonTouchUpDragEnter) forControlEvents:UIControlEventTouchDragEnter];
    [self.view addSubview:_recordButton];
    
    _playRecordButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _playRecordButton.frame = CGRectMake(50 , 200, 300 , 50);
    [_playRecordButton setTitle:@"播放录音" forState:UIControlStateNormal];
    [_playRecordButton addTarget:self action:@selector(playRecordButtonTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_playRecordButton];
    
}

- (void)playRecordButtonTouchUpInside {
    
    if (_recordFilePath) {
        _player = [[AVAudioPlayer alloc] initWithData:[NSData dataWithContentsOfFile:_recordFilePath] error:nil];
        [_session setCategory:AVAudioSessionCategoryPlayback error:nil];
        [_player play];
    }
}

//摁住说话
- (void)recordButtonTouchDown {
    //info.plist配置权限
    if (![self canRecord]) {
        NSLog(@"请启用麦克风-设置/隐私/麦克风");
    }
    
    //禁止其它按钮交互
    [self setupUserEnabled:NO];
    
    //音量视图
    if (_volumeBgView) {
        [_volumeBgView removeFromSuperview];
        _volumeBgView = nil;
    }
    
    CGFloat viewWidth = self.view.frame.size.width/2.5;
    _volumeBgView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, viewWidth+20)];
    _volumeBgView.center = self.view.center;
    _volumeBgView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    _volumeBgView.layer.cornerRadius = 10;
    [self.view addSubview:_volumeBgView];
    
    _volumeImageView = [[UIImageView alloc] initWithFrame:CGRectMake(15, 10, viewWidth - 30, viewWidth - 30)];
    _volumeImageView.image = [UIImage imageNamed:@"voice_1"];
    [_volumeBgView addSubview:_volumeImageView];
    
    _volumeLabel = [[UILabel alloc] init];
    _volumeLabel.frame = CGRectMake(5, viewWidth - 10, viewWidth-10, 25);
    _volumeLabel.font = [UIFont systemFontOfSize:14];
    _volumeLabel.layer.masksToBounds = YES;
    _volumeLabel.layer.cornerRadius = 5;
    _volumeLabel.textAlignment = NSTextAlignmentCenter;
    _volumeLabel.textColor = [UIColor whiteColor];
    _volumeLabel.text = @"手指上滑，取消发送";
    [_volumeBgView addSubview:_volumeLabel];
    
    //开始录音
    _countDown = 60;
    //添加定时器
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(refreshLabelText) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    
    _session =[AVAudioSession sharedInstance];
    NSError *sessionError;
    [_session setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
    
    if (_session == nil) {
        NSLog(@"Error creating session: %@",[sessionError description]);
    } else {
        [_session setActive:YES error:nil];
    }
    
    //获取文件沙盒地址
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    _recordFilePath = [path stringByAppendingString:@"/RRecord.wav"];
    
    //设置参数
    NSDictionary *recordSetting = @{AVFormatIDKey: @(kAudioFormatLinearPCM),
                                    AVSampleRateKey: @8000.00f,
                                    AVNumberOfChannelsKey: @1,
                                    AVLinearPCMBitDepthKey: @16,
                                    AVLinearPCMIsNonInterleaved: @NO,
                                    AVLinearPCMIsFloatKey: @NO,
                                    AVLinearPCMIsBigEndianKey: @NO};
    
    _recorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:_recordFilePath] settings:recordSetting error:nil];
    if (_recorder) {
        _recorder.meteringEnabled = YES;
        [_recorder prepareToRecord];
        [_recorder record];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self recordButtonTouchUpInside];
        });
        
    }else{
        NSLog(@"音频格式和文件存储格式不匹配,无法初始化Recorder");
    }
}

- (void)refreshLabelText {
    
    [_recorder updateMeters];
    
    float   level;
    float   minDecibels = -80.0f;
    float   decibels    = [_recorder averagePowerForChannel:0];
    
    if (decibels < minDecibels) {
        level = 0.0f;
    } else if (decibels >= 0.0f) {
        level = 1.0f;
    } else {
        float   root            = 2.0f;
        float   minAmp          = powf(10.0f, 0.05f * minDecibels);
        float   inverseAmpRange = 1.0f / (1.0f - minAmp);
        float   amp             = powf(10.0f, 0.05f * decibels);
        float   adjAmp          = (amp - minAmp) * inverseAmpRange;
        
        level = powf(adjAmp, 1.0f / root);
    }
    
    NSInteger voice = level*10 + 1;
    voice = voice > 8 ? 8 : voice;
    
    NSString *imageIndex = [NSString stringWithFormat:@"voice_%ld", voice];
    if (_isLeaveSpeakBtn) {
        _volumeImageView.image = [UIImage imageNamed:@"rc_ic_volume_cancel"];
    } else {
        _volumeImageView.image = [UIImage imageNamed:imageIndex];
    }
    
    _countDown --;
    
    if (_countDown < 10 && _countDown > 0) {
        _volumeLabel.text = [NSString stringWithFormat:@"还剩 %ld 秒",(long)_countDown];
    }
    //超时自动发送
    if (_countDown < 1) {
        [self recordButtonTouchUpInside];
    }
}

//松开发送
- (void)recordButtonTouchUpInside {
    NSLog(@"recordButtonTouchUpInside");
    
    _isLeaveSpeakBtn = NO;
    
    if (!_timer) { //松开之后为何还会触发
        return;
    }
    
    //停止录音 移除定时器
    [_timer invalidate];
    _timer = nil;
    
    if ([_recorder isRecording]) {
        [_recorder stop];
    }
    
    //允许其它按钮交互
    [self setupUserEnabled:YES];
    
    if (_countDown > 59) {
        _volumeImageView.image = [UIImage imageNamed:@"rc_ic_volume_wraning"];
        _volumeLabel.text = @"说话时间太短";
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (_volumeBgView) {
                [_volumeBgView removeFromSuperview];
                _volumeBgView = nil;
            }
        });
        return;
    }
    
    if (_volumeBgView) {
        [_volumeBgView removeFromSuperview];
        _volumeBgView = nil;
    }
    
    //音频数据
    //    [NSData dataWithContentsOfFile:_recordFilePath];
}

- (void)setupUserEnabled:(BOOL)enable {
    _playRecordButton.enabled = enable;
}

//上滑离开按钮区域松开 取消
- (void)recordButtonTouchUpOutside {
    NSLog(@"recordButtonTouchUpOutside");
    
    _isLeaveSpeakBtn = NO;
    
    //停止录音 移除定时器
    [_timer invalidate];
    _timer = nil;
    
    if ([_recorder isRecording]) {
        [_recorder stop];
    }
    
    //允许其它按钮交互
    [self setupUserEnabled:YES];
    
    if (_volumeBgView) {
        [_volumeBgView removeFromSuperview];
        _volumeBgView = nil;
    }
}

- (void)recordButtonTouchUpDragExit {
    NSLog(@"recordButtonTouchUpDragExit");
    _isLeaveSpeakBtn = YES;
    
    _volumeLabel.text = @"松开手指，取消发送";
    _volumeLabel.backgroundColor =  [UIColor redColor];
    _volumeImageView.image = [UIImage imageNamed:@"rc_ic_volume_cancel"];
}

- (void)recordButtonTouchUpDragEnter {
    NSLog(@"recordButtonTouchUpDragEnter");
    _isLeaveSpeakBtn = NO;
    _volumeLabel.text = @"手指上滑，取消发送";
    _volumeLabel.backgroundColor =  [UIColor clearColor];
}

//检查是否拥有麦克风权限
- (BOOL)canRecord {
    __block BOOL bCanRecord = YES;
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    if ([audioSession respondsToSelector:@selector(requestRecordPermission:)]) {
        [audioSession performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
            if (granted) {
                bCanRecord = YES;
            } else {
                bCanRecord = NO;
            }
        }];
    }
    return bCanRecord;
}


@end
