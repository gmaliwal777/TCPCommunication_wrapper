//
//  MediaUploading.h
//  Boku
//
//  Created by Ghanshyam on 9/23/15.
//  Copyright (c) 2015 Plural Voice. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TCPCommunication.h"


@class Media;

@protocol MediaUploadDelegate <NSObject>

-(void)mediaUploaded:(Media *)media;
-(void)mediaUploadFailure:(Media *)media;

@end


@interface MediaUploading : NSObject<TCPDelegate>{
    
    
    
    
    //It indicate last Index of HIGH_LEVEL_MEDIA
    int     highLevelLastMediaIndex;
}


@property (nonatomic, weak) id<MediaUploadDelegate> delegate;

@property (atomic, strong)  NSMutableArray      *arrMedias;


/**
 *  Reference to tcp Communication
 */
@property (nonatomic, strong) TCPCommunication    *communication;


/**
 *  Used to upload media
 *
 *  @param media : media which is being uploaded
 */
-(void)uploadMedia:(Media *)media;


/**
 *  Used to get shared instance of uploading media
 *
 *  @param mediaIdentifier Media Identifier
 *
 *  @return Media/nil
 */
-(Media *)lookForSharedMediaWithMediaIdentifier:(NSString *)mediaIdentifier;


-(void)reconnect;

@end
