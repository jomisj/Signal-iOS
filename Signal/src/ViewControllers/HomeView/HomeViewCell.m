//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "HomeViewCell.h"
#import "OWSAvatarBuilder.h"
#import "Signal-Swift.h"
#import <SignalMessaging/OWSFormat.h>
#import <SignalMessaging/OWSMath.h>
#import <SignalMessaging/OWSUserProfile.h>
#import <SignalMessaging/SignalMessaging-Swift.h>
#import <SignalServiceKit/OWSMessageManager.h>
#import <SignalServiceKit/TSContactThread.h>
#import <SignalServiceKit/TSGroupThread.h>

NS_ASSUME_NONNULL_BEGIN

@interface HomeViewCell ()

@property (nonatomic) AvatarImageView *avatarView;
@property (nonatomic) UIStackView *payloadView;
@property (nonatomic) UIStackView *topRowView;
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UILabel *snippetLabel;
@property (nonatomic) UILabel *dateTimeLabel;
@property (nonatomic) UIView *unreadBadge;
@property (nonatomic) UILabel *unreadLabel;

@property (nonatomic, nullable) ThreadViewModel *thread;
@property (nonatomic, nullable) OWSContactsManager *contactsManager;

@property (nonatomic, readonly) NSMutableArray<NSLayoutConstraint *> *viewConstraints;

@end

#pragma mark -

@implementation HomeViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(nullable NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        [self commontInit];
    }
    return self;
}

// `[UIView init]` invokes `[self initWithFrame:...]`.
- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self commontInit];
    }

    return self;
}

- (void)commontInit
{
    OWSAssert(!self.avatarView);

    self.backgroundColor = [UIColor whiteColor];

    _viewConstraints = [NSMutableArray new];

    self.avatarView = [[AvatarImageView alloc] init];
    [self.contentView addSubview:self.avatarView];
    [self.avatarView autoSetDimension:ALDimensionWidth toSize:self.avatarSize];
    [self.avatarView autoSetDimension:ALDimensionHeight toSize:self.avatarSize];
    [self.avatarView autoPinLeadingToSuperviewMargin];
    [self.avatarView autoVCenterInSuperview];
    [self.avatarView setContentHuggingHigh];
    [self.avatarView setCompressionResistanceHigh];
    // Ensure that the cell's contents never overflow the cell bounds.
    [self.avatarView autoPinEdgeToSuperviewMargin:ALEdgeTop relation:NSLayoutRelationGreaterThanOrEqual];
    [self.avatarView autoPinEdgeToSuperviewMargin:ALEdgeBottom relation:NSLayoutRelationGreaterThanOrEqual];

    self.payloadView = [UIStackView new];
    self.payloadView.axis = UILayoutConstraintAxisVertical;
    [self.contentView addSubview:self.payloadView];
    [self.payloadView autoPinLeadingToTrailingEdgeOfView:self.avatarView offset:self.avatarHSpacing];
    [self.payloadView autoVCenterInSuperview];
    // Ensure that the cell's contents never overflow the cell bounds.
    [self.payloadView autoPinEdgeToSuperviewMargin:ALEdgeTop relation:NSLayoutRelationGreaterThanOrEqual];
    [self.payloadView autoPinEdgeToSuperviewMargin:ALEdgeBottom relation:NSLayoutRelationGreaterThanOrEqual];
    // We pin the payloadView traillingEdge later, as part of the "Unread Badge" logic.

    self.nameLabel = [UILabel new];
    self.nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.nameLabel.font = self.nameFont;
    [self.nameLabel setContentHuggingHorizontalLow];
    [self.nameLabel setCompressionResistanceHorizontalLow];

    self.dateTimeLabel = [UILabel new];
    [self.dateTimeLabel setContentHuggingHorizontalHigh];
    [self.dateTimeLabel setCompressionResistanceHorizontalHigh];

    self.topRowView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.nameLabel,
        self.dateTimeLabel,
    ]];
    self.topRowView.axis = UILayoutConstraintAxisHorizontal;
    self.topRowView.alignment = UIStackViewAlignmentLastBaseline;
    [self.payloadView addArrangedSubview:self.topRowView];

    self.snippetLabel = [UILabel new];
    self.snippetLabel.font = [self snippetFont];
    self.snippetLabel.numberOfLines = 1;
    self.snippetLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.payloadView addArrangedSubview:self.snippetLabel];
    [self.snippetLabel setContentHuggingHorizontalLow];
    [self.snippetLabel setCompressionResistanceHorizontalLow];

    self.unreadLabel = [UILabel new];
    self.unreadLabel.textColor = [UIColor whiteColor];
    self.unreadLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.unreadLabel.textAlignment = NSTextAlignmentCenter;

    self.unreadBadge = [NeverClearView new];
    self.unreadBadge.backgroundColor = [UIColor ows_materialBlueColor];
    [self.unreadBadge addSubview:self.unreadLabel];
    [self.unreadLabel autoCenterInSuperview];
    [self.unreadLabel setContentHuggingHigh];
    [self.unreadLabel setCompressionResistanceHigh];

    self.payloadView.userInteractionEnabled = NO;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (NSString *)cellReuseIdentifier
{
    return NSStringFromClass([self class]);
}

- (void)initializeLayout
{
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
}

- (nullable NSString *)reuseIdentifier
{
    return NSStringFromClass(self.class);
}

- (void)configureWithThread:(ThreadViewModel *)thread
            contactsManager:(OWSContactsManager *)contactsManager
      blockedPhoneNumberSet:(NSSet<NSString *> *)blockedPhoneNumberSet
{
    [self configureWithThread:thread
              contactsManager:contactsManager
        blockedPhoneNumberSet:blockedPhoneNumberSet
              overrideSnippet:nil
                 overrideDate:nil];
}

- (void)configureWithThread:(ThreadViewModel *)thread
            contactsManager:(OWSContactsManager *)contactsManager
      blockedPhoneNumberSet:(NSSet<NSString *> *)blockedPhoneNumberSet
            overrideSnippet:(nullable NSAttributedString *)overrideSnippet
               overrideDate:(nullable NSDate *)overrideDate
{
    OWSAssertIsOnMainThread();
    OWSAssert(thread);
    OWSAssert(contactsManager);
    OWSAssert(blockedPhoneNumberSet);

    self.thread = thread;
    self.contactsManager = contactsManager;

    BOOL hasUnreadMessages = thread.hasUnreadMessages;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(otherUsersProfileDidChange:)
                                                 name:kNSNotificationName_OtherUsersProfileDidChange
                                               object:nil];
    [self updateNameLabel];
    [self updateAvatarView];

    self.payloadView.spacing = 0.f;
    self.topRowView.spacing = self.topRowHSpacing;

    // We update the fonts every time this cell is configured to ensure that
    // changes to the dynamic type settings are reflected.
    self.snippetLabel.font = [self snippetFont];

    if (overrideSnippet) {
        self.snippetLabel.attributedText = overrideSnippet;
    } else {
        self.snippetLabel.attributedText =
            [self attributedSnippetForThread:thread blockedPhoneNumberSet:blockedPhoneNumberSet];
    }

    self.dateTimeLabel.text
        = (overrideDate ? [self stringForDate:overrideDate] : [self stringForDate:thread.lastMessageDate]);

    if (hasUnreadMessages && overrideSnippet == nil) {
        self.dateTimeLabel.textColor = [UIColor ows_light90Color];
        self.dateTimeLabel.font = self.dateTimeFont.ows_mediumWeight;
    } else {
        self.dateTimeLabel.textColor = [UIColor ows_light60Color];
        self.dateTimeLabel.font = self.dateTimeFont;
    }

    NSUInteger unreadCount = thread.unreadCount;
    if (unreadCount == 0 || overrideSnippet != nil) {
        [self.viewConstraints addObject:[self.payloadView autoPinTrailingToSuperviewMargin]];
    } else {
        [self.contentView addSubview:self.unreadBadge];

        self.unreadLabel.text = [OWSFormat formatInt:(int)unreadCount];
        self.unreadLabel.font = self.unreadFont;
        const int unreadBadgeHeight = (int)ceil(self.unreadLabel.font.lineHeight * 1.5f);
        self.unreadBadge.layer.cornerRadius = unreadBadgeHeight / 2;

        [NSLayoutConstraint autoSetPriority:UILayoutPriorityDefaultHigh
                             forConstraints:^{
                                 // This is a bit arbitrary, but it should scale with the size of dynamic text
                                 CGFloat minMargin = CeilEven(unreadBadgeHeight * .5);

                                 // Spec check. Should be 12pts (6pt on each side) when using default font size.
                                 OWSAssert(UIFont.ows_dynamicTypeBodyFont.pointSize != 17 || minMargin == 12);

                                 [self.viewConstraints addObjectsFromArray:@[
                                     [self.unreadBadge autoMatchDimension:ALDimensionWidth
                                                              toDimension:ALDimensionWidth
                                                                   ofView:self.unreadLabel
                                                               withOffset:minMargin],
                                     // badge sizing
                                     [self.unreadBadge autoSetDimension:ALDimensionWidth
                                                                 toSize:unreadBadgeHeight
                                                               relation:NSLayoutRelationGreaterThanOrEqual],
                                     [self.unreadBadge autoSetDimension:ALDimensionHeight toSize:unreadBadgeHeight],
                                 ]];
                             }];

        const CGFloat kMinVMargin = 5;
        [self.viewConstraints addObjectsFromArray:@[
            // Horizontally, badge is inserted after the tail of the payloadView, pushing back the date *and* snippet
            // view
            [self.payloadView autoPinEdge:ALEdgeTrailing
                                   toEdge:ALEdgeLeading
                                   ofView:self.unreadBadge
                               withOffset:-self.topRowHSpacing],
            [self.unreadBadge autoPinTrailingToSuperviewMargin],
            [self.unreadBadge autoPinEdgeToSuperviewEdge:ALEdgeTop
                                               withInset:kMinVMargin
                                                relation:NSLayoutRelationGreaterThanOrEqual],
            [self.unreadBadge autoPinEdgeToSuperviewEdge:ALEdgeBottom
                                               withInset:kMinVMargin
                                                relation:NSLayoutRelationGreaterThanOrEqual],

            // Vertically, badge is positioned vertically by aligning it's label *subview's* baseline.
            // This allows us a single visual baseline of text across the top row across [name, dateTime,
            // optional(unread count)]
            [self.unreadLabel autoAlignAxis:ALAxisBaseline toSameAxisOfView:self.dateTimeLabel]
        ]];
    }
}

- (void)updateAvatarView
{
    OWSContactsManager *contactsManager = self.contactsManager;
    if (contactsManager == nil) {
        OWSFail(@"%@ contactsManager should not be nil", self.logTag);
        self.avatarView.image = nil;
        return;
    }

    ThreadViewModel *thread = self.thread;
    if (thread == nil) {
        OWSFail(@"%@ thread should not be nil", self.logTag);
        self.avatarView.image = nil;
        return;
    }

    self.avatarView.image = [OWSAvatarBuilder buildImageForThread:thread.threadRecord
                                                         diameter:self.avatarSize
                                                  contactsManager:contactsManager];
}

- (NSAttributedString *)attributedSnippetForThread:(ThreadViewModel *)thread
                             blockedPhoneNumberSet:(NSSet<NSString *> *)blockedPhoneNumberSet
{
    OWSAssert(thread);

    BOOL isBlocked = NO;
    if (!thread.isGroupThread) {
        NSString *contactIdentifier = thread.contactIdentifier;
        isBlocked = [blockedPhoneNumberSet containsObject:contactIdentifier];
    }
    BOOL hasUnreadMessages = thread.hasUnreadMessages;

    NSMutableAttributedString *snippetText = [NSMutableAttributedString new];
    if (isBlocked) {
        // If thread is blocked, don't show a snippet or mute status.
        [snippetText
            appendAttributedString:[[NSAttributedString alloc]
                                       initWithString:NSLocalizedString(@"HOME_VIEW_BLOCKED_CONTACT_CONVERSATION",
                                                          @"A label for conversations with blocked users.")
                                           attributes:@{
                                               NSFontAttributeName : self.snippetFont.ows_mediumWeight,
                                               NSForegroundColorAttributeName : [UIColor ows_light90Color],
                                           }]];
    } else {
        if ([thread isMuted]) {
            [snippetText appendAttributedString:[[NSAttributedString alloc]
                                                    initWithString:@"\ue067  "
                                                        attributes:@{
                                                            NSFontAttributeName : [UIFont ows_elegantIconsFont:9.f],
                                                            NSForegroundColorAttributeName : (hasUnreadMessages
                                                                    ? [UIColor colorWithWhite:0.1f alpha:1.f]
                                                                    : [UIColor ows_light60Color]),
                                                        }]];
        }
        NSString *displayableText = thread.lastMessageText;
        if (displayableText) {
            [snippetText appendAttributedString:[[NSAttributedString alloc]
                                                    initWithString:displayableText
                                                        attributes:@{
                                                            NSFontAttributeName :
                                                                (hasUnreadMessages ? self.snippetFont.ows_mediumWeight
                                                                                   : self.snippetFont),
                                                            NSForegroundColorAttributeName :
                                                                (hasUnreadMessages ? [UIColor ows_light90Color]
                                                                                   : [UIColor ows_light60Color]),
                                                        }]];
        }
    }

    return snippetText;
}

#pragma mark - Date formatting

- (NSString *)stringForDate:(nullable NSDate *)date
{
    if (date == nil) {
        OWSProdLogAndFail(@"%@ date was unexpectedly nil", self.logTag);
        return @"";
    }

    return [DateUtil formatDateShort:date];
}

#pragma mark - Constants

- (UIFont *)unreadFont
{
    return [UIFont ows_dynamicTypeCaption1Font].ows_mediumWeight;
}

- (UIFont *)dateTimeFont
{
    return [UIFont ows_dynamicTypeCaption1Font];
}

- (UIFont *)snippetFont
{
    return [UIFont ows_dynamicTypeSubheadlineFont];
}

- (UIFont *)nameFont
{
    return [UIFont ows_dynamicTypeBodyFont].ows_mediumWeight;
}

// Used for profile names.
- (UIFont *)nameSecondaryFont
{
    return [UIFont ows_dynamicTypeFootnoteFont];
}

- (NSUInteger)avatarSize
{
    return 48.f;
}

- (NSUInteger)avatarHSpacing
{
    return 12.f;
}

// Using an NSUInteger precludes us from negating this value
- (CGFloat)topRowHSpacing
{
    return 6.f;
}

#pragma mark - Reuse

- (void)prepareForReuse
{
    [super prepareForReuse];

    [NSLayoutConstraint deactivateConstraints:self.viewConstraints];
    [self.viewConstraints removeAllObjects];

    self.thread = nil;
    self.contactsManager = nil;
    self.avatarView.image = nil;

    [self.unreadBadge removeFromSuperview];

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Name

- (void)otherUsersProfileDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    NSString *recipientId = notification.userInfo[kNSNotificationKey_ProfileRecipientId];
    if (recipientId.length == 0) {
        return;
    }

    if (![self.thread isKindOfClass:[TSContactThread class]]) {
        return;
    }

    if (![self.thread.contactIdentifier isEqualToString:recipientId]) {
        return;
    }

    [self updateNameLabel];
    [self updateAvatarView];
}

- (void)updateNameLabel
{
    OWSAssertIsOnMainThread();

    self.nameLabel.font = self.nameFont;

    ThreadViewModel *thread = self.thread;
    if (thread == nil) {
        OWSFail(@"%@ thread should not be nil", self.logTag);
        self.nameLabel.attributedText = nil;
        return;
    }

    OWSContactsManager *contactsManager = self.contactsManager;
    if (contactsManager == nil) {
        OWSFail(@"%@ contacts manager should not be nil", self.logTag);
        self.nameLabel.attributedText = nil;
        return;
    }

    NSAttributedString *name;
    if (thread.isGroupThread) {
        if (thread.name.length == 0) {
            name = [[NSAttributedString alloc] initWithString:[MessageStrings newGroupDefaultTitle]];
        } else {
            name = [[NSAttributedString alloc] initWithString:thread.name];
        }
    } else {
        name = [contactsManager attributedContactOrProfileNameForPhoneIdentifier:thread.contactIdentifier
                                                                     primaryFont:self.nameFont
                                                                   secondaryFont:self.nameSecondaryFont];
    }

    self.nameLabel.attributedText = name;
}

@end

NS_ASSUME_NONNULL_END
