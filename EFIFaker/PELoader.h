//
//  PELoader.h
//  EFIFaker
//
//  Created by Gwynne Raskind on 1/13/14.
//  Copyright (c) 2014 Elwea Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PELoader : NSObject

@property(nonatomic,readonly) NSURL *url;
@property(nonatomic,readonly) NSData *rawContents;
@property(nonatomic,readonly) void *entryPoint;

- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;

- (BOOL)mapAndReturnError:(NSError **)error;

@end
