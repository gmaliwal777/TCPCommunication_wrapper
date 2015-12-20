//
//  ImageQuickRender.m
//  ImageQuickRendering
//
//  Created by Ghanshyam on 10/10/14.
//  Copyright (c) 2014 Ghanshyam. All rights reserved.
//

#import "ImageQuickRender.h"



ImageQuickRender* imageRender;

@implementation ImageQuickRender

/**
 @discussion This method used to setup communication with ReadStream / WriteStream
 */
-(BOOL)setUpCommunication:(NSString *)remoteImageFile localImageFile:(NSString *)localImageFile{
    totalBytesRead = 0;
    
    //Creating Read Stream with server image file
    CFURLRef    readUrlRef = CFURLCreateWithString(NULL, (CFStringRef)remoteImageFile, NULL);
    CFStringRef requestMethod = CFSTR("GET");
    CFHTTPMessageRef myRequest = CFHTTPMessageCreateRequest(NULL, requestMethod, readUrlRef, kCFHTTPVersion1_1);
    readStream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, myRequest);
    
    //Creating WriteStream with local image file
    localMediaURL = localImageFile;
    CFURLRef    writeUrlRef = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)localImageFile, kCFURLPOSIXPathStyle, FALSE);
    writeStream = CFWriteStreamCreateWithFile(kCFAllocatorDefault, writeUrlRef);
    
    //Setting up ReadStream Property
    if (readStream) {
        CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
    }
    
    //Setting up WriteStream Property
    if (writeStream) {
        CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
    }
    
    
    //Initially YES for downloading
    _downloading = YES;
    if (readStream == NULL || writeStream == NULL) {
        //Closing Stream
        //[self closeStream];
        return NO;
    }
    return [self openStream];
}

/**
 @discussion This method used to open stream
 @return     it returns YES/NO basis on Steram response
 */

-(BOOL)openStream{
    NSLog(@"opening stream");
    if (readStream == NULL || writeStream == NULL) {
        return NO;
    }else{
        CFStreamStatus readStatus = CFReadStreamGetStatus(readStream);
        CFStreamStatus writeStatus = CFWriteStreamGetStatus(writeStream);
        if (readStatus == kCFStreamStatusNotOpen ||
            writeStatus == kCFStreamStatusNotOpen) {
            [self setReadWriteCallBack];
            
            [self scheduleInRunLoop];
            BOOL status1 = CFReadStreamOpen(readStream);
            BOOL status2 = CFWriteStreamOpen(writeStream);
            if (!status1 || !status2) {
                return NO;
            }
        }
        return YES;
    }
}

/**
  @discussion  This Method used to close existing stream
 */

-(void)closeStream{
    NSLog(@"streaming close");
    NSLog(@"downloading is %d for url %@",_downloading,localMediaURL);
    if (_downloading) {
        [self deleteLocalInCompleteFile];
    }
    
    [self reSetReadWriteCallBack];
    [self rescheduleInRunLoop];
    if (readStream) {
        CFReadStreamClose(readStream);
        CFRelease(readStream);
        readStream = NULL;
    }
    if (writeStream) {
        CFWriteStreamClose(writeStream);
        CFRelease(writeStream);
        writeStream = NULL;
    }
}

/**
 @discussion This method used to set callback for Read/Write streams
 */
-(void)setReadWriteCallBack{
    context.version = 0;
    context.info = (__bridge void *)(self);
    context.retain = nil;
    context.release = nil;
    context.copyDescription = nil;
    CFOptionFlags readStreamEvents = kCFStreamEventOpenCompleted|kCFStreamEventErrorOccurred|kCFStreamEventEndEncountered|kCFStreamEventHasBytesAvailable;
    CFReadStreamSetClient(readStream, readStreamEvents, &CFReadStreamCallBack, &context);
    
    CFOptionFlags writeStreamEvents = kCFStreamEventErrorOccurred|kCFStreamEventOpenCompleted|kCFStreamEventEndEncountered|kCFStreamEventCanAcceptBytes;
    CFWriteStreamSetClient(writeStream, writeStreamEvents, &CFWriteStreamCallBack, &context);
}

/**
 @discussion this method used to remove callback for read/write streams
 */
-(void)reSetReadWriteCallBack{
    //ReadStream set client
    if (readStream) {
        CFOptionFlags readStreamEvent = kCFStreamEventNone;
        CFReadStreamSetClient(readStream, readStreamEvent, NULL, NULL);
    }
    
    
    //WriteStream set client
    if (writeStream) {
        CFOptionFlags writeStreamEvent = kCFStreamEventNone;
        CFWriteStreamSetClient(writeStream, writeStreamEvent, NULL, NULL);
    }
    
}

/**
 @discussion this method used to schedule read/write stream in Runloop
 */
-(void)scheduleInRunLoop{
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    //Registering readstream in current runloop
    if (readStream) {
        CFReadStreamScheduleWithRunLoop(readStream, runloop, kCFRunLoopCommonModes);
    }
    
    //Registering writestream in current runloop
    if (writeStream) {
        CFWriteStreamScheduleWithRunLoop(writeStream, runloop, kCFRunLoopCommonModes);
    }
    
}

/**
 @discussion this method used to remove read/write stream from Runloop
 */
-(void)rescheduleInRunLoop{
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    if (readStream) {
        CFReadStreamUnscheduleFromRunLoop(readStream, runloop, kCFRunLoopCommonModes);
    }
    
    if (writeStream) {
        CFWriteStreamUnscheduleFromRunLoop(writeStream, runloop, kCFRunLoopCommonModes);
    }
}

/**
 @discussion This is ReadStream CallBack
 @param      Stream is representing readstream
 @param      type is representing event type on readstream
 @param      context gives origin class reference
 */
static void CFReadStreamCallBack(CFReadStreamRef stream, CFStreamEventType type, void *context){
    imageRender = (__bridge ImageQuickRender *)context;
    switch (type) {
        case kCFStreamEventOpenCompleted:
            NSLog(@"read stream opened successfully");
            break;
        case kCFStreamEventErrorOccurred:
            NSLog(@"read stream event error occurred");
            dispatch_once_t onceDispatchFlag = imageRender.onceDispatch;
            dispatch_once(&onceDispatchFlag, ^{
                if ([imageRender->_delegate conformsToProtocol:@protocol(ImageRenderDelegate)]
                    &&[imageRender->_delegate respondsToSelector:@selector(communicationNotReadyToFileDownload)]) {
                    //imageRender.downloading = NO;
                    [imageRender->_delegate communicationNotReadyToFileDownload];
                }
            });
            break;
        case kCFStreamEventEndEncountered:
            if ([imageRender->_delegate conformsToProtocol:@protocol(ImageRenderDelegate)]
                &&[imageRender->_delegate respondsToSelector:@selector(fileDownloadingDone:)]) {
                imageRender.downloading = NO;
                [imageRender closeStream];
                [imageRender->_delegate fileDownloadingDone:imageRender->_imgData];
            }
            break;
        case kCFStreamEventHasBytesAvailable:
            NSLog(@"read stream available to read");
            dispatch_once_t onceDispatcher = imageRender.onceDispatch;
            dispatch_once(&onceDispatcher, ^{
                if ([imageRender->_delegate conformsToProtocol:@protocol(ImageRenderDelegate)]
                    &&[imageRender->_delegate respondsToSelector:@selector(communicationReadyToFileDownload)]) {
                    if (!imageRender->_imgData) {
                        imageRender->_imgData = [[NSMutableData alloc] init];
                    }
                    [imageRender->_delegate communicationReadyToFileDownload];
                }
            });
            if (imageRender->totalBytesRead>0) {
                //This condition appears when more data to be accepted until read file
                //reached to end of file
                [imageRender downloadImageFile];
            }
            
            break;
        default:
            break;
    }
}

/**
 @discussion This is WriteStream CallBack
 @param      Stream is representing WriteStream
 @param      type is representing event type on WriteStream
 @param      context gives origin class reference
 */
static void CFWriteStreamCallBack(CFWriteStreamRef stream, CFStreamEventType type, void *pInfo){
    imageRender = (__bridge ImageQuickRender *)pInfo;
    switch (type) {
        case kCFStreamEventOpenCompleted:
            NSLog(@"write stream opened successfully");
            break;
        case kCFStreamEventErrorOccurred:
            NSLog(@"write stream event error occurred");
            dispatch_once_t onceWriteDispatcher = imageRender.onceDispatch;
            dispatch_once(&onceWriteDispatcher, ^{
                if ([imageRender->_delegate conformsToProtocol:@protocol(ImageRenderDelegate)]
                    &&[imageRender->_delegate respondsToSelector:@selector(communicationNotReadyToFileDownload)]) {
                    //imageRender.downloading = NO;
                    [imageRender->_delegate communicationNotReadyToFileDownload];
                }
            });
            break;
        case kCFStreamEventEndEncountered:
            NSLog(@"write stream event end occurred");
            break;
        case kCFStreamEventCanAcceptBytes:
            NSLog(@"ready to accept bytes");
            break;
        default:
            break;
    }
}


#pragma mark--
#pragma mark--
-(void)downloadImageFile{
    
    
    uint8_t buffer[10240];
    while (CFReadStreamHasBytesAvailable(imageRender->readStream)) {
        NSInteger bytesRead = CFReadStreamRead(imageRender->readStream, buffer, sizeof(buffer));
        if (bytesRead<=0) {
            NSLog(@"bytes read failure");
            break;
        }else if(bytesRead>0){
            if ([imageRender->_delegate conformsToProtocol:@protocol(ImageRenderDelegate)]
                &&[imageRender->_delegate respondsToSelector:@selector(didReceiveData:)]) {
                [imageRender->_delegate didReceiveData:[NSData dataWithBytes:(const void *)buffer length:bytesRead]];
            }
            [imageRender->_imgData appendBytes:(const void *)buffer length:bytesRead];
            CFWriteStreamWrite(imageRender->writeStream, buffer, bytesRead);
            imageRender->totalBytesRead += bytesRead;
        }
    }
}

#pragma mark--
#pragma mark-- Dealloc Method
-(void)dealloc{
    NSLog(@"quick rendere dealloc called");
    [self closeStream];
    self.imgData = nil;
}

/**
 @discussion Below method used to delete locally created file which is incomplete
 */
-(void)deleteLocalInCompleteFile{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSLog(@"deleteLocalInCompleteFile path is %@",localMediaURL);
    if ([fileManager fileExistsAtPath:localMediaURL]) {
        //deleting file locally
        _downloading = NO;
        NSLog(@"deleting file locally");
        [fileManager removeItemAtPath:localMediaURL error:NULL];
    }
}


@end
