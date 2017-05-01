//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "Contact.h"
#import <SignalServiceKit/ContactsManagerProtocol.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const OWSContactsManagerSignalAccountsDidChangeNotification;

@class UIFont;
@class SignalAccount;

/**
 * Get latest Signal contacts, and be notified when they change.
 */
@interface OWSContactsManager : NSObject <ContactsManagerProtocol>

@property (nonnull, readonly) NSCache<NSString *, UIImage *> *avatarCache;

// signalAccountMap and signalAccounts hold the same data.
// signalAccountMap is for lookup. signalAccounts contains the accounts
// ordered by display order.
@property (atomic, readonly) NSDictionary<NSString *, SignalAccount *> *signalAccountMap;
@property (atomic, readonly) NSArray<SignalAccount *> *signalAccounts;

- (nullable SignalAccount *)signalAccountForRecipientId:(NSString *)recipientId;

- (Contact *)getOrBuildContactForPhoneIdentifier:(NSString *)identifier;

#pragma mark - System Contact Fetching

- (void)requestSystemContactsOnce;
- (void)fetchSystemContactsIfAlreadyAuthorized;

// TODO: Remove this method.
- (NSArray<Contact *> *)signalContacts;

- (NSString *)displayNameForPhoneIdentifier:(nullable NSString *)identifier;
- (NSString *)displayNameForContact:(Contact *)contact;
- (NSString *)displayNameForSignalAccount:(SignalAccount *)signalAccount;
- (nullable UIImage *)imageForPhoneIdentifier:(nullable NSString *)identifier;
- (NSAttributedString *)formattedDisplayNameForSignalAccount:(SignalAccount *)signalAccount font:(UIFont *_Nonnull)font;
- (NSAttributedString *)formattedFullNameForContact:(Contact *)contact font:(UIFont *)font;
- (NSAttributedString *)formattedFullNameForRecipientId:(NSString *)recipientId font:(UIFont *)font;

// TODO migrate to CNContact?
- (BOOL)hasAddressBook;

+ (NSComparator _Nonnull)contactComparator;

@end

NS_ASSUME_NONNULL_END
