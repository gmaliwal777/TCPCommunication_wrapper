//
//  MediaUploading.m
//  Boku
//
//  Created by Ghanshyam on 9/23/15.
//  Copyright (c) 2015 Plural Voice. All rights reserved.
//

#import "MediaUploading.h"
#import "Media.h"
#import "NSData+Base64.h"


@implementation MediaUploading

#pragma mark - Super Class Methods
-(id)init{
    self = [super init];
    if (self) {
        self.communication = [[TCPCommunication alloc] initWithNetworkType:NO];
        self.communication.delegate = self;
        [self.communication setUpCommunicationStream];
        
        self.arrMedias = [[NSMutableArray alloc] init];
        highLevelLastMediaIndex = 0;
        
    }
    return self;
}

-(void)dealloc{
    
    NSLog(@"MediaUploading dealloc");
    
    //Destroying TCP Socket
    [self.communication releaseData];
    [self.communication closeStream];
    self.communication = nil;
    
    [self.arrMedias removeAllObjects];
    self.arrMedias = nil;
    highLevelLastMediaIndex = 0;
}

#pragma mark - Instance Methods
/**
 *  Used to get shared instance of uploading media
 *
 *  @param mediaIdentifier Media Identifier
 *
 *  @return Media/nil
 */
-(Media *)lookForSharedMediaWithMediaIdentifier:(NSString *)mediaIdentifier{
    //@synchronized(arrMedias){
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.mediaIdentifier CONTAINS[cd] %@",mediaIdentifier];
        NSArray *arrFilteredMedia = [self.arrMedias filteredArrayUsingPredicate:predicate];
        if (arrFilteredMedia.count>0) {
            Media *media = [arrFilteredMedia objectAtIndex:0];
            return media;
        }
        return nil;
    //}
}


-(void)processMedia:(NSDictionary *)dictResponse{
    
    @synchronized(self.arrMedias){
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.mediaIdentifier CONTAINS[cd] %@",[dictResponse objectForKey:@"media_identifier"]];
        NSArray *arrFilteredMedia = [self.arrMedias filteredArrayUsingPredicate:predicate];
        
        
        if (arrFilteredMedia.count>0) {
            Media *media = [arrFilteredMedia objectAtIndex:0];
            
            
            //Remove existing Offline Media file , which was created before for backup to deal with failure.
            [CommonFunctions removeOfflineMedia:media bokuUser:media.bokuXMPPJID];
            
            
            if ([dictResponse objectForKey:@"url"]) {
                media.mediaURL = [dictResponse objectForKey:@"url"];
            }
            
            if ([dictResponse objectForKey:@"thumb_url"]) {
                media.thumbURL = [dictResponse objectForKey:@"thumb_url"];
            }
            
            if ([_delegate conformsToProtocol:@protocol(MediaUploadDelegate)] &&
                [_delegate respondsToSelector:@selector(mediaUploaded:)]) {
                
                [_delegate mediaUploaded:media];
                
            }
            
            media.isProcessing = NO;
            
            [self.arrMedias removeObject:media];
            highLevelLastMediaIndex--;
            
        }
        
        if (self.arrMedias.count>0) {
            [self processNextMedia];
        }
    }
    
}

/**
 *  Used to upload media
 *
 *  @param media : media which is being uploaded
 */
-(void)uploadMedia:(Media *)media{
    
    //@synchronized(arrMedias){
        if (media.mediaPriority == LOW_LEVEL_MEDIA) {
            //Low level media is being added in queue FIFO methodology
            
            //Adding Media to Queue for Media uploading process
            [self.arrMedias addObject:media];
        }else{
            //Media is default HIGH_LEVEL_MEDIA
            [self.arrMedias insertObject:media atIndex:highLevelLastMediaIndex];
            highLevelLastMediaIndex++;
        }
    
    
        if (media.mediaPriority == HIGH_LEVEL_MEDIA) {
            //we save media for Offline process later
            [CommonFunctions saveOfflineMedia:media bokuUser:media.bokuXMPPJID];
        }
        
        
        if (!_communication.processing && _communication.isLive) {
            [self processNextMedia];
        }else if (_communication.isDisConnected){
            NSLog(@"communication was disconnected1");
            [_delegate mediaUploadFailure:media];
            [self reconnect];
        }else{
            //Worst case , which is indicating media uploading failure
            [_delegate mediaUploadFailure:media];
        }
    //}
    
}

-(void)processNextMedia{
   // @synchronized(arrMedias){
        Media *media = [self.arrMedias objectAtIndex:0];
        
        if (!_communication.processing && _communication.isLive && self.arrMedias.count>0) {
            
            NSMutableDictionary *dictRequest = [NSMutableDictionary dictionaryWithObjectsAndKeys:[media fileType],@"fileType",[media fileExtension],@"extension",media.mediaIdentifier,@"media_identifier",@"iOS",@"device_type", nil];
            
            
            //below if condition for uploading profile image for group
            if ([media.mediaMetaData isKindOfClass:[NSDictionary class]]) {
                
                NSDictionary *dictMetaData = media.mediaMetaData;
                if ([[dictMetaData objectForKey:@"mediaType"] isEqualToString:@"group_image"]) {
                    
                    [dictRequest setObject:@"group_image" forKey:@"mediaType"];
                    
                }
                if ([dictMetaData objectForKey:@"mediaName"]){
                    
                    [dictRequest setObject:[dictMetaData objectForKey:@"mediaName"] forKey:@"mediaName"];
                    
                }
            }
            
            
            
            NSData *dataRequest = [ NSJSONSerialization dataWithJSONObject:dictRequest options:NSJSONWritingPrettyPrinted error:NULL];
            NSString *strRequest = [[NSString alloc] initWithData:dataRequest encoding:NSUTF8StringEncoding];
            
            NSString *mediaRequest = @"";
            
            if (media.mediaData) {
                
                media.isProcessing = YES;
                
                //NSData *newData = UIImageJPEGRepresentation(_groupImage, 0.8);
                mediaRequest = [media.mediaData base64EncodedString];
                mediaRequest = [mediaRequest stringByAppendingString:@"#@@#"];
                mediaRequest = [mediaRequest stringByAppendingString:strRequest];
                mediaRequest = [mediaRequest stringByAppendingString:media.mediaAction];
                
                NSLog(@"request being processed == %@",mediaRequest);
                
                [_communication sendRequest:mediaRequest];
                
            }
            
        }else if (_communication.isDisConnected){
            NSLog(@"communication was disconnected");
            [_delegate mediaUploadFailure:media];
            [self reconnect];
        }else{
            //Worst case , which is indicating media uploading failure
            [_delegate mediaUploadFailure:media];
        }
    //}
    
}

-(void)reconnect{
    [_communication setUpCommunicationStream];
}

#pragma mark - TCPDelegate
-(void)dataReceived:(NSData *)response{
    
    NSError *error;
    NSDictionary *dictResponse = [NSJSONSerialization JSONObjectWithData:response options:NSJSONReadingMutableContainers error:&error];
    
    if (!error && [[dictResponse valueForKey:@"status"] intValue] == 200 ) {
        
        if ([dictResponse objectForKey:@"fileType"]) {
            
            NSString *fileType = [dictResponse objectForKey:@"fileType"];
            if ([fileType isEqualToString:@"image"]
                ||[fileType isEqualToString:@"video"]
                || [fileType isEqualToString:@"audio"]) {
                
                [self processMedia:dictResponse];
                
            }
        }
    }
}

-(void)connectionOpened{
    //@synchronized(arrMedias){
        if (self.arrMedias.count>0) {
            [self processNextMedia];
        }
    //}
    
}

-(void)connectionClosed{
    //@synchronized(arrMedias){
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.isProcessing == %@",[NSNumber numberWithBool:YES]];
        NSArray *arrProcessingMedia = [self.arrMedias filteredArrayUsingPredicate:predicate];
        if (arrProcessingMedia.count>0) {
            Media *media = [arrProcessingMedia objectAtIndex:0];
            media.isProcessing = NO;
            [_delegate mediaUploadFailure:media];
        }
    //}
    
}

-(void)requestSent{
    
}



@end
