//
// Created by Nicky Romeijn on 23-06-16.
// Copyright (c) 2016 Adversitement. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Models/O2MBatch.h"
#import "O2MDispatcherDelegate.h"
#import "O2MLogger.h"


@interface O2MDispatcher : NSObject {
    NSString* _appName;
    O2MLogger* _logger;
    NSURLSession* _session;
}

@property (nonatomic, weak) id <O2MDispatcherDelegate>delegate;

-(id)init:(NSString*)appName;
-(void) dispatchWithEndpoint:(NSString*)endpoint batch:(O2MBatch*)batch sessionId:(NSString*)sessionIdentifier;
-(void) successHandler;
-(void) errorHandler;
-(NSURLSession *) urlSession;
@end
