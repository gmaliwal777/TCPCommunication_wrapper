//
//  TCPCommunication.m
//  TCPWebserviceConsumption
//
//  Created by Ghanshyam on 08/07/14.
//  Copyright (c) 2014 Ghanshyam. All rights reserved.
//

#import "TCPCommunication.h"

@implementation TCPCommunication


-(id)initWithNetworkType:(BOOL)voipIdentifier{
    self = [super init];
    if (self) {
        voipFlag = voipIdentifier;
        containerData = [[NSMutableData alloc] init];
        _isDisConnected = NO;
    }
    return self;
}

#pragma mark--
#pragma mark-- Communication Method

/**
 @discussion Used to initiate TCP connection and configure Input & Output Streams .
 Input stream used to get response from server and Output Stream used
 to write data over server
 */

-(void)setUpCommunicationStream{
    
    if (self.inputStream && self.outputStream) {
        //already TCP Connection is existing
        NSLog(@"streams are existing");
        return;
    }
    
    _isLive = NO;
    _isDisConnected = NO;
    
    //Basically CFStream needed to connect with Remote Host.
    CFReadStreamRef  readStream;
    CFWriteStreamRef writeStream;
    
    //for development
//    CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)@"46.101.62.191", 8353, &readStream, &writeStream);

    //Client testing
    CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)@"46.101.62.191", 8252, &readStream, &writeStream);


    
    //Specifying to close and release underlying socket on release of Streams
    CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket,
                            kCFBooleanTrue);
    CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket,
                             kCFBooleanTrue);
    
    //Setting Up Stream Object for Communication with App
    self.inputStream  = (__bridge_transfer NSInputStream *)readStream;
    [_inputStream setDelegate:self];
    [_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    if (voipFlag) {
        //NSLog(@"network type is VOIP");
        [_inputStream setProperty:NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType];
    }
    [_inputStream setProperty:NSStreamNetworkServiceTypeVideo forKey:NSStreamNetworkServiceType];
    
    [_inputStream open];
    
    
    self.outputStream = (__bridge_transfer NSOutputStream *)writeStream;
    [_outputStream setDelegate:self];
    [_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    if (voipFlag) {
        [_outputStream setProperty:NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType];
    }
    [_outputStream open];
}



#pragma mark--
#pragma mark-- Stream Delegate
-(void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode{
    @try {
        if (aStream == _inputStream) {
            switch (eventCode) {
                case NSStreamEventNone:
                    //NSLog(@"server is not up");
                    break;
                case NSStreamEventErrorOccurred:
                    NSLog(@"input stream event error");
                    [self closeStream];
                    break;
                case NSStreamEventOpenCompleted:
                    NSLog(@"input stream created successfully");
                    
                    break;
                case NSStreamEventHasBytesAvailable:
                    if (!data) {
                        data = [[NSMutableData alloc] init];
                    }
                    uint8_t buffer[10240];
                    NSInteger bufferSize;
                    
                    while ([_inputStream hasBytesAvailable]) {
                        bufferSize = [_inputStream read:buffer maxLength:sizeof(buffer)];
                        if (bufferSize>0)
                        {
                            NSString *output = [[NSString alloc] initWithBytes:buffer length:bufferSize encoding:NSASCIIStringEncoding];
                            //NSLog(@"output is %@",output);
                            if ([output rangeOfString:@"\n"].location == NSNotFound ) {
                                @synchronized(containerData){
                                    if (containerData) {
                                        [containerData appendBytes:(const void *)buffer length:bufferSize];
                                    }
                                }
                            }else{
                                int lineCount = (int)[[output componentsSeparatedByString:@"\n"] count];
                                NSData *newData = nil;
                                for (int counter = 0; counter<(lineCount-1); counter++) {
                                    NSString *dataContent = [[output componentsSeparatedByString:@"\n"] objectAtIndex:counter];
                                    NSData *tmpData1 = [dataContent dataUsingEncoding:NSUTF8StringEncoding];
                                    @synchronized(containerData){
                                        if (containerData) {
                                            [containerData appendData:tmpData1];
                                            newData = [NSData dataWithData:containerData];
                                            @synchronized(self){
                                                [self dataReceived:newData];
                                            }
                                            if (containerData) {
                                                [containerData setLength:0];
                                            }
                                        }
                                    }
                                }
                                NSString *nextString = [[output componentsSeparatedByString:@"\n"] objectAtIndex:lineCount-1];
                                if (nextString.length > 0) {
                                    NSData *tmpData2 = [nextString dataUsingEncoding:NSUTF8StringEncoding];
                                    
                                    @synchronized(containerData){
                                        if (containerData) {
                                            [containerData appendData:tmpData2];
                                        }
                                    }
                                }
                            }
                        }else if (bufferSize<0){
                           // NSLog(@"breaking end of stream");
                            break;
                        }
                    }
                    break;
                case NSStreamEventEndEncountered:
                    NSLog(@"input stream event end encountered");
                    [self closeStream];
                    break;
                default:
                    break;
            }
        }else if (aStream == _outputStream){
            switch (eventCode) {
                case NSStreamEventErrorOccurred:
                    NSLog(@"output stream error occurred");
                    [self closeStream];
                    break;
                case NSStreamEventHasSpaceAvailable:
                    [self processingPendingRequest];
                    
                    NSLog(@"outputstream space available to write");
                    break;
                case NSStreamEventOpenCompleted:
                    NSLog(@"outputstream stream openend successfully");
                    _isLive = YES;
                    if ([_delegate conformsToProtocol:@protocol(TCPDelegate)] &&
                        [_delegate respondsToSelector:@selector(connectionOpened)]) {
                        NSLog(@"connectionOpened delegate");
                        [_delegate connectionOpened];
                    }
                    break;
                case NSStreamEventEndEncountered:
                    NSLog(@"output stream event end occurred");
                    [self closeStream];
                    break;
                default:
                    break;
            }
        }
    }
    @catch (NSException *exception) {
        //NSLog(@"tcp communication exception ");
    }
    @finally {
        
    }
    
    
}

#pragma mark--
#pragma mark-- Custom Method
-(void)closeStream{
    
    
    if (_inputStream) {
        NSLog(@"inside inputstream");
        //Closing InputStream default remove it from RunLoop, if itself scheduled
        //in Runloop.
        [_inputStream close];
        _inputStream.delegate = self;
        self.inputStream = nil;
    }
    
    
    if (_outputStream) {
        NSLog(@"inside outputstream");
        //Closing OutputStream default remove it from RunLoop, if itself scheduled
        //in Runloop.
        [_outputStream close];
        _outputStream.delegate = self;
        self.outputStream = nil;
    }
    
    _isLive = NO;
    _isDisConnected = YES;
    
    if ([_delegate conformsToProtocol:@protocol(TCPDelegate)] &&
        [_delegate respondsToSelector:@selector(connectionClosed)]) {
        NSLog(@"connection closed delegate");
        [_delegate connectionClosed];
    }
    
}


-(void)dataReceived:(NSData *)responseData{
    NSData *dataVal = [NSData dataWithData:responseData];
    
    //NSString *response = [[NSString alloc] initWithData:dataVal encoding:NSUTF8StringEncoding];
    //NSLog(@"response is %@",response);
    [self processingPendingRequest];
    if ([_delegate conformsToProtocol:@protocol(TCPDelegate)] &&
        [_delegate respondsToSelector:@selector(dataReceived:)]) {
            [_delegate dataReceived:dataVal];
    }
}

-(void)processingPendingRequest{
    _processing = NO;
    if (_lastRequest) {
        NSLog(@"pending request");
        [self sendRequest:_lastRequest];
    }
}


-(void)sendRequest:(NSString *)request{
    //NSLog(@"space available is %d",[_outputStream has]);
    if (_outputStream && [_outputStream hasSpaceAvailable] && _processing == NO) {
        //NSLog(@"processed request is%@",request);
        self.lastRequest = nil;
        _processing = YES;
        NSData *requestData = [[NSData alloc] initWithData:[request dataUsingEncoding:NSUTF8StringEncoding]];
        int index = 0;
        int totalLen =(int) [requestData length];
        
        NSLog(@"total len is %d",totalLen);
        uint8_t buffer[1024];
        uint8_t *readBytes = (uint8_t *)[requestData bytes];
        
        while (index < totalLen) {
            if (_outputStream && [_outputStream hasSpaceAvailable]) {
                int indexLen =  (1024>(totalLen-index))?(totalLen-index):1024;
                
                (void)memcpy(buffer, readBytes, indexLen);
                
                int written =(int) [_outputStream write:buffer maxLength:indexLen];
                
                NSLog(@"written is is %d",written);
                if (written < 0) {
                    break;
                }
                index += written;
                readBytes += written;
                NSLog(@"index is %d",index);
                
            }
            
        }
        
        if ([_delegate conformsToProtocol:@protocol(TCPDelegate)]
            &&[_delegate respondsToSelector:@selector(requestSent)]) {
            [_delegate requestSent];
        }
    }else{
        self.lastRequest = request;
    }
}


-(void)dealloc{
    
    [self closeStream];
    @synchronized(containerData){
        containerData = nil;
    }
    data = nil;
}


-(void)releaseData{
    containerData = nil;
    data = nil;
}

@end
