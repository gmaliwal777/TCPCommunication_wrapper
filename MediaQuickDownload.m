//
//  MediaQuickDownload.m
//  Forgeter
//
//  Created by Ghanshyam on 6/2/15.
//  Copyright (c) 2015 Ravi Taylor. All rights reserved.
//

#import "MediaQuickDownload.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>


@implementation MediaQuickDownload

#pragma mark-- Super Class Methods


-(void)dealloc{
    NSLog(@"MediaQuickDownload dealloc");
//    [self setValue:@"done" forKey:@"isDownloaded"];
    //[self stopDownloading];
}


#pragma mark-- Instance Methods

-(void)stopDownloading{
    //Stoping download
    NSLog(@"stopDownloading media quick downloader");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
//    [self setValue:@"done" forKey:@"isDownloaded"];
    
    self.imgMedia = nil;
    self.mediaData = nil;
    if (_mediaQuickRenderer) {
        _mediaQuickRenderer.delegate = nil;
        [_mediaQuickRenderer closeStream];
    }
    self.mediaQuickRenderer =nil;
}


/**
 *  Used to download media file
 *
 *  @param remoteURL : Remote URL of file
 *  @param localURL  : Local URL of file , where to write data
 */
-(void)downloadMedia:(NSString *)remoteURL loaclURL:(NSString *)localURL{
    
    self.mediaQuickRenderer    =   [[ImageQuickRender alloc] init];
    self.mediaQuickRenderer.delegate = self;
    
    //NSString *loalTempURL = [];
    BOOL setUp = [_mediaQuickRenderer setUpCommunication:remoteURL localImageFile:localURL];
    
    if (setUp) {
        
        NSLog(@"initial setup is done");
        
    }
}


#pragma mark--
#pragma mark-- Image Rendering Delegate
-(void)communicationReadyToFileDownload{
    //ImageQuickRender is setup for downloading media
    NSLog(@"started file downloading");
    [_mediaQuickRenderer downloadImageFile];
}

-(void)communicationNotReadyToFileDownload{
    //ImageQuickRender is not setup for downloading media
    NSLog(@"communication failed to download media");
    if ([_delegate conformsToProtocol:@protocol(MediaQuickDownloaderDelegate)]
        && [_delegate respondsToSelector:@selector(mediaDownloadFailure)]) {
        [_delegate mediaDownloadFailure];
    }
}

-(void)fileDownloadingDone:(NSData *)data{
    //ImageQuickRender is done with file downloading
    //Stoping download
    
    [self stopDownloading];
    
//    [self setValue:@"done" forKey:@"isDownloaded"];
    
    if ([_delegate conformsToProtocol:@protocol(MediaQuickDownloaderDelegate)]
        && [_delegate respondsToSelector:@selector(mediaDownloadedSuccessfully)]) {
        [_delegate mediaDownloadedSuccessfully];
    }
}


-(void)fileDownloadingError{
    //ImageQuickRender failed while downloading
    NSLog(@"file downloading error");
    if ([_delegate conformsToProtocol:@protocol(MediaQuickDownloaderDelegate)]
        && [_delegate respondsToSelector:@selector(mediaDownloadFailure)]) {
        [_delegate mediaDownloadFailure];
    }
}

-(void)didReceiveData:(NSData *)data{

    if (!_mediaData) {
        self.mediaData = [[NSMutableData alloc] init];
    }
    
    [_mediaData appendData:data];
    
    if (_imgMedia) {
        [self.imgMedia setImage:[UIImage imageWithData:_mediaData]];
    }
    
}

@end
