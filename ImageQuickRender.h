//
//  ImageQuickRender.h
//  ImageQuickRendering
//
//  Created by Ghanshyam on 10/10/14.
//  Copyright (c) 2014 Ghanshyam. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ImageRenderDelegate <NSObject>
    -(void)communicationReadyToFileDownload;
    -(void)communicationNotReadyToFileDownload;
    -(void)fileDownloadingDone:(NSData *)data;
    -(void)fileDownloadingError;
    -(void)didReceiveData:(NSData *)data;
@end

@interface ImageQuickRender : NSObject{
    CFReadStreamRef             readStream;
    CFWriteStreamRef            writeStream;
    CFStreamClientContext       context;
    NSInteger                   totalBytesRead;
    NSInteger                   totalBytesWritten;
    NSString                    *localMediaURL;
}


@property (nonatomic,strong)    NSMutableData               *imgData;
@property (nonatomic,weak)      id<ImageRenderDelegate>     delegate;
@property (nonatomic,assign)    BOOL                        downloading;
@property (nonatomic,assign)    dispatch_once_t             onceDispatch;


-(BOOL)setUpCommunication:(NSString *)remoteImageFile localImageFile:(NSString *)localImageFile;
-(void)downloadImageFile;
-(void)closeStream;


@end
