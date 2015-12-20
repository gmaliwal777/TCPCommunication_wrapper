//
//  TCPCommunication.h
//  TCPWebserviceConsumption
//
//  Created by Ghanshyam on 08/07/14.
//  Copyright (c) 2014 Ghanshyam. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol TCPDelegate <NSObject>

@optional
-(void)dataReceived:(NSData *)response;
-(void)connectionClosed;
-(void)connectionOpened;
-(void)requestSent;

@end

@interface TCPCommunication : NSObject<NSStreamDelegate>{
    NSMutableData      *data;
    NSMutableData      *containerData;
    
    BOOL               voipFlag;
    
}

@property (nonatomic,strong)  NSString           *lastRequest;
@property (nonatomic,strong)  dispatch_queue_t   backgroundQueue;
@property (nonatomic,weak)    id<TCPDelegate>    delegate;
@property (nonatomic,strong)  NSInputStream      *inputStream;
@property (nonatomic,strong)  NSOutputStream     *outputStream;

@property (nonatomic, assign)   BOOL               processing;


@property (nonatomic, assign)   BOOL                isLive;


@property (nonatomic, assign)   BOOL                isDisConnected;

-(id)initWithNetworkType:(BOOL)voipIdentifier;
-(void)setUpCommunicationStream;
-(void)sendRequest:(NSString *)request;
-(void)closeStream;
-(void)releaseData;

@end
