//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "TSCall.h"
#import "TSContactThread.h"
#import <YapDatabase/YapDatabaseConnection.h>
#import <YapDatabase/YapDatabaseTransaction.h>

NS_ASSUME_NONNULL_BEGIN

NSUInteger TSCallCurrentSchemaVersion = 1;

@interface TSCall ()

@property (nonatomic, getter=wasRead) BOOL read;

@property (nonatomic, readonly) NSUInteger callSchemaVersion;

@end

#pragma mark -

@implementation TSCall

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                   withCallNumber:(NSString *)contactNumber
                         callType:(RPRecentCallType)callType
                         inThread:(TSContactThread *)thread
{
    self = [super initInteractionWithTimestamp:timestamp inThread:thread];

    if (!self) {
        return self;
    }

    _callSchemaVersion = TSCallCurrentSchemaVersion;
    _callType = callType;
    if (_callType == RPRecentCallTypeIncomingMissed
        || _callType == RPRecentCallTypeIncomingMissedBecauseOfChangedIdentity) {
        _read = NO;
    } else {
        _read = YES;
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return self;
    }

    if (self.callSchemaVersion < 1) {
        // Assume user has already seen any call that predate read-tracking
        _read = YES;
    }

    _callSchemaVersion = TSCallCurrentSchemaVersion;

    return self;
}

- (OWSInteractionType)interactionType
{
    return OWSInteractionType_Call;
}

- (NSString *)previewTextWithTransaction:(YapDatabaseReadTransaction *)transaction
{
    // We don't actually use the `transaction` but other sibling classes do.
    switch (_callType) {
        case RPRecentCallTypeIncoming:
            return NSLocalizedString(@"INCOMING_CALL", @"");
        case RPRecentCallTypeOutgoing:
            return NSLocalizedString(@"OUTGOING_CALL", @"");
        case RPRecentCallTypeIncomingMissed:
            return NSLocalizedString(@"MISSED_CALL", @"");
        case RPRecentCallTypeOutgoingIncomplete:
            return NSLocalizedString(@"OUTGOING_INCOMPLETE_CALL", @"");
        case RPRecentCallTypeIncomingIncomplete:
            return NSLocalizedString(@"INCOMING_INCOMPLETE_CALL", @"");
        case RPRecentCallTypeIncomingMissedBecauseOfChangedIdentity:
            return NSLocalizedString(@"INFO_MESSAGE_MISSED_CALL_DUE_TO_CHANGED_IDENITY", @"info message text shown in conversation view");
        case RPRecentCallTypeIncomingDeclined:
            return NSLocalizedString(@"INCOMING_DECLINED_CALL",
                                     @"info message recorded in conversation history when local user declined a call");
    }
}

#pragma mark - OWSReadTracking

- (uint64_t)expireStartedAt
{
    return 0;
}

- (BOOL)shouldAffectUnreadCounts
{
    return YES;
}

- (void)markAsReadAtTimestamp:(uint64_t)readTimestamp
              sendReadReceipt:(BOOL)sendReadReceipt
                  transaction:(YapDatabaseReadWriteTransaction *)transaction
{

    OWSAssert(transaction);

    if (_read) {
        return;
    }

    DDLogDebug(
        @"%@ marking as read uniqueId: %@ which has timestamp: %llu", self.logTag, self.uniqueId, self.timestamp);
    _read = YES;
    [self saveWithTransaction:transaction];
    [self touchThreadWithTransaction:transaction];

    // Ignore sendReadReceipt - it doesn't apply to calls.
}

#pragma mark - Methods

- (void)updateCallType:(RPRecentCallType)callType
{
    DDLogInfo(@"%@ updating call type of call: %d with uniqueId: %@ which has timestamp: %llu",
        self.logTag,
        (int)self.callType,
        self.uniqueId,
        self.timestamp);

    _callType = callType;

    [self.dbReadWriteConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *_Nonnull transaction) {
        [self saveWithTransaction:transaction];
        
        // redraw any thread-related unread count UI.
        [self touchThreadWithTransaction:transaction];
    }];
}

- (BOOL)isIncoming
{
    switch (self.callType) {
        case RPRecentCallTypeIncoming:
        case RPRecentCallTypeIncomingMissed:
        case RPRecentCallTypeIncomingIncomplete:
        case RPRecentCallTypeIncomingMissedBecauseOfChangedIdentity:
        case RPRecentCallTypeIncomingDeclined:
            return YES;
        case RPRecentCallTypeOutgoing:
        case RPRecentCallTypeOutgoingIncomplete:
            return NO;
    }
}

@end

NS_ASSUME_NONNULL_END
