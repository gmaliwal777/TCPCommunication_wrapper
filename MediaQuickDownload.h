//
//  MediaQuickDownload.h
//  Forgeter
//
//  Created by Ghanshyam on 6/2/15.
//  Copyright (c) 2015 Ravi Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ImageQuickRender.h"


@protocol MediaQuickDownloaderDelegate <NSObject>
-(void)mediaDownloadedSuccessfully;
-(void)mediaDownloadFailure;
@end

@interface MediaQuickDownload : NSObject<ImageRenderDelegate>{
    NSString        *localMediaURL;
    
    BOOL            isDownloaded;
}

@property (nonatomic,weak)      UIImageView                 *imgMedia;
@property (nonatomic,strong)    ImageQuickRender            *mediaQuickRenderer;
@property (nonatomic,strong)    NSMutableData               *mediaData;
@property (nonatomic,assign)    MEDIA_TYPE                   mediaType;

@property (nonatomic,weak)      id<MediaQuickDownloaderDelegate>    delegate;

-(void)downloadMedia:(NSString *)remoteURL loaclURL:(NSString *)localURL;
-(void)stopDownloading;

@end
