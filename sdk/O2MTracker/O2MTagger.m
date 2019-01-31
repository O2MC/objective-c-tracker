//
//  O2MTagger.m
//  O2MTagger
//
//  Created by Nicky Romeijn on 16-06-16.
//  Copyright © 2016 Adversitement. All rights reserved.
//

#import "O2MTagger.h"

#import "O2MBatchManager.h"
#import "O2MConfig.h"
#import "O2MEventManager.h"
#import "Models/O2MEvent.h"
#import "O2MLogger.h"
#import "O2MUtil.h"

@interface O2MTagger()

// Managers
@property O2MBatchManager *batchManager;
@property O2MEventManager *eventManager;

// Misc
@property NSTimer * batchCreateTimer;
@property O2MLogger *logger;
@property dispatch_queue_t tagQueue;

@end

@implementation O2MTagger

-(O2MTagger *) init :(NSString *)endpoint :(NSNumber *)dispatchInterval; {
    self = [super init];

    _batchManager = [[O2MBatchManager alloc] init];
    _eventManager = [[O2MEventManager alloc] init];
    _logger = [[O2MLogger alloc] initWithTopic:"tagger"];

    _tagQueue = dispatch_queue_create("io.o2mc.sdk", DISPATCH_QUEUE_SERIAL);

    [self->_batchManager setEndpoint:endpoint];
    [self setDispatchInterval:dispatchInterval];
    [self batchWithInterval:O2MConfig.batchInterval];

    return self;
}

#pragma mark - Internal batch methods

-(void) batchWithInterval :(NSNumber *) dispatchInterval; {
    if (self->_batchCreateTimer) {
        [self->_batchCreateTimer invalidate];
        self->_batchCreateTimer = nil;
    }
    self->_batchCreateTimer = [NSTimer timerWithTimeInterval:[dispatchInterval floatValue] target:self selector:@selector(createBatch:) userInfo:nil repeats:YES];

    // Start the dispatch timer
    [NSRunLoop.mainRunLoop addTimer:self->_batchCreateTimer forMode:NSRunLoopCommonModes];
}

-(void) createBatch:(NSTimer *)timer;{
    dispatch_async(_tagQueue, ^{
        // Check if there are any events to batch
        if(self->_eventManager.eventCount == 0) return;

        // Collect events from the event manager and push them to the batchmanager.
        // We copy the events to a new array since the events would be emptied by ARC before they
        // could be added to a batch.
        [self->_batchManager createBatchWithEvents:[[NSArray alloc] initWithArray:self->_eventManager.events]];
        [self->_eventManager clearEvents];
    });
}

#pragma mark - Configuration methods
-(void) setDispatchInterval:(nonnull NSNumber*)dispatchInterval; {
    [self->_batchManager dispatchWithInterval:dispatchInterval];
}

-(NSString*) getEndpoint; {
    return self->_batchManager.endpoint;
}

-(void) setEndpoint :(NSString *) endpoint; {
    [self->_batchManager setEndpoint:endpoint];
}


-(void) setMaxRetries :(NSInteger)maxRetries; {
    [_batchManager setMaxRetries: maxRetries];
}

-(void)setIdentifier :(NSString*) uniqueIdentifier; {
    [self->_batchManager setSessionIdentifier:uniqueIdentifier];
}

-(void)setSessionIdentifier; {
    [self->_batchManager setSessionIdentifier:[[NSUUID UUID] UUIDString]];
}

#pragma mark - Control methods

-(void) clearFunnel; {
    dispatch_async(_tagQueue, ^{
        [self->_eventManager clearEvents];
        [self->_logger logD:@"clearing the funnel"];
    });
}

-(void)stop {
    [self stop:YES];
}

-(void)stop:(BOOL) clearFunnel; {
    [self->_logger logI:@"stopping tracking"];
    [self->_batchManager stop];
    [self stopTimer];

    if (clearFunnel == NO) return;

    [self clearFunnel];
}

-(void)stopTimer; {
    if(self->_batchCreateTimer) {
        [self->_batchCreateTimer invalidate];
        self->_batchCreateTimer = nil;
    }
}

-(void)resume; {
    if(![[self batchCreateTimer] isValid]) {
        [self batchWithInterval:O2MConfig.batchInterval];
    }

    if(![self->_batchManager isDispatching]) {
        [self->_batchManager dispatchWithInterval:O2MConfig.dispatchInterval];
    }
}

#pragma mark - Tracking methods

-(void)track :(NSString*)eventName; {
    dispatch_async(_tagQueue, ^{
        if (![self->_batchManager isDispatching]) return;
        [self->_logger logD:@"Track %@", eventName];

        [self->_eventManager addEvent: [[O2MEvent alloc] init:eventName]];
    });
}

-(void)trackWithProperties:(NSString*)eventName properties:(NSDictionary*)properties;
{
    dispatch_async(_tagQueue, ^{
        if (![self->_batchManager isDispatching]) return;
        [self->_logger logD:@"Track %@:%@", eventName, properties];

        [self->_eventManager addEvent: [[O2MEvent alloc] initWithProperties:eventName
                                                                 properties:properties]];
    });
}

@end



