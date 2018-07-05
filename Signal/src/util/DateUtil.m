//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "DateUtil.h"
#import <SignalMessaging/NSString+OWS.h>
#import <SignalMessaging/OWSFormat.h>
#import <SignalServiceKit/NSDate+OWS.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const DATE_FORMAT_WEEKDAY = @"EEEE";

@implementation DateUtil

+ (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        [formatter setLocale:[NSLocale currentLocale]];
        [formatter setTimeStyle:NSDateFormatterNoStyle];
        [formatter setDateStyle:NSDateFormatterShortStyle];
    });
    return formatter;
}

+ (NSDateFormatter *)weekdayFormatter {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        [formatter setLocale:[NSLocale currentLocale]];
        [formatter setDateFormat:DATE_FORMAT_WEEKDAY];
    });
    return formatter;
}

+ (NSDateFormatter *)timeFormatter {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        [formatter setLocale:[NSLocale currentLocale]];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
        [formatter setDateStyle:NSDateFormatterNoStyle];
    });
    return formatter;
}

+ (NSDateFormatter *)monthAndDayFormatter
{
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        [formatter setLocale:[NSLocale currentLocale]];
        formatter.dateFormat = @"MMM d";
    });
    return formatter;
}

+ (NSDateFormatter *)shortDayOfWeekFormatter
{
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        [formatter setLocale:[NSLocale currentLocale]];
        formatter.dateFormat = @"E";
    });
    return formatter;
}

+ (BOOL)dateIsOlderThanToday:(NSDate *)date
{
    return [self dateIsOlderThanToday:date now:[NSDate date]];
}

+ (BOOL)dateIsOlderThanToday:(NSDate *)date now:(NSDate *)now
{
    NSInteger dayDifference = [self daysFromFirstDate:date toSecondDate:now];
    return dayDifference > 0;
}

+ (BOOL)dateIsOlderThanOneWeek:(NSDate *)date
{
    return [self dateIsOlderThanOneWeek:date now:[NSDate date]];
}

+ (BOOL)dateIsOlderThanOneWeek:(NSDate *)date now:(NSDate *)now
{
    NSInteger dayDifference = [self daysFromFirstDate:date toSecondDate:now];
    return dayDifference > 6;
}

+ (BOOL)dateIsToday:(NSDate *)date
{
    return [self dateIsToday:date now:[NSDate date]];
}

+ (BOOL)dateIsToday:(NSDate *)date now:(NSDate *)now
{
    NSInteger dayDifference = [self daysFromFirstDate:date toSecondDate:now];
    return dayDifference == 0;
}

+ (BOOL)dateIsThisYear:(NSDate *)date
{
    return [self dateIsThisYear:date now:[NSDate date]];
}

+ (BOOL)dateIsThisYear:(NSDate *)date now:(NSDate *)now
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    return (
        [calendar component:NSCalendarUnitYear fromDate:date] == [calendar component:NSCalendarUnitYear fromDate:now]);
}

+ (BOOL)dateIsYesterday:(NSDate *)date
{
    return [self dateIsYesterday:date now:[NSDate date]];
}

+ (BOOL)dateIsYesterday:(NSDate *)date now:(NSDate *)now
{
    NSInteger dayDifference = [self daysFromFirstDate:date toSecondDate:now];
    return dayDifference == 1;
}

// Returns the difference in days, ignoring hours, minutes, seconds.
// If both dates are the same date, returns 0.
// If firstDate is a day before secondDate, returns 1.
//
// Note: Assumes both dates use the "current" calendar.
+ (NSInteger)daysFromFirstDate:(NSDate *)firstDate toSecondDate:(NSDate *)secondDate
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSCalendarUnit units = NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
    NSDateComponents *comp1 = [calendar components:units fromDate:firstDate];
    NSDateComponents *comp2 = [calendar components:units fromDate:secondDate];
    [comp1 setHour:12];
    [comp2 setHour:12];
    NSDate *date1 = [calendar dateFromComponents:comp1];
    NSDate *date2 = [calendar dateFromComponents:comp2];
    return [[calendar components:NSCalendarUnitDay fromDate:date1 toDate:date2 options:0] day];
}

+ (NSString *)formatPastTimestampRelativeToNow:(uint64_t)pastTimestamp
{
    OWSCAssert(pastTimestamp > 0);

    uint64_t nowTimestamp = [NSDate ows_millisecondTimeStamp];
    BOOL isFutureTimestamp = pastTimestamp >= nowTimestamp;

    NSDate *pastDate = [NSDate ows_dateWithMillisecondsSince1970:pastTimestamp];
    NSString *dateString;
    if (isFutureTimestamp || [self dateIsToday:pastDate]) {
        dateString = NSLocalizedString(@"DATE_TODAY", @"The current day.");
    } else if ([self dateIsYesterday:pastDate]) {
        dateString = NSLocalizedString(@"DATE_YESTERDAY", @"The day before today.");
    } else {
        dateString = [[self dateFormatter] stringFromDate:pastDate];
    }
    return [[dateString rtlSafeAppend:@" "] rtlSafeAppend:[[self timeFormatter] stringFromDate:pastDate]];
}

+ (NSString *)formatTimestampShort:(uint64_t)timestamp
{
    return [self formatDateShort:[NSDate ows_dateWithMillisecondsSince1970:timestamp]];
}

+ (NSString *)formatDateShort:(NSDate *)date
{
    OWSAssert(date);

    NSString *dateTimeString;
    if (![DateUtil dateIsThisYear:date]) {
        dateTimeString = [[DateUtil dateFormatter] stringFromDate:date];
    } else if ([DateUtil dateIsOlderThanOneWeek:date]) {
        dateTimeString = [[DateUtil monthAndDayFormatter] stringFromDate:date];
    } else if ([DateUtil dateIsOlderThanToday:date]) {
        dateTimeString = [[DateUtil shortDayOfWeekFormatter] stringFromDate:date];
    } else {
        dateTimeString = [[DateUtil timeFormatter] stringFromDate:date];
    }

    return dateTimeString.uppercaseString;
}

+ (NSString *)formatTimestampAsTime:(uint64_t)timestamp
{
    return [self formatDateAsTime:[NSDate ows_dateWithMillisecondsSince1970:timestamp]];
}

+ (NSString *)formatDateAsTime:(NSDate *)date
{
    OWSAssert(date);

    NSString *dateTimeString = [[DateUtil timeFormatter] stringFromDate:date];
    return dateTimeString.uppercaseString;
}

+ (NSString *)formatTimestampAsTime:(uint64_t)timestamp maxRelativeDurationMinutes:(NSInteger)maxRelativeDurationMinutes
{
    NSDate *date = [NSDate ows_dateWithMillisecondsSince1970:timestamp];
    NSDate *now = [NSDate new];

    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSInteger minutesDiff
        = MAX(0, [[calendar components:NSCalendarUnitMinute fromDate:date toDate:now options:0] minute]);

    // Treat anything in the last two minutes as "now", so that we
    // don't have to worry about pluralization while formatting.
    if (minutesDiff <= 1) {
        return NSLocalizedString(@"DATE_NOW", @"The present; the current time.");
    } else if (minutesDiff <= maxRelativeDurationMinutes) {
        NSString *minutesString = [OWSFormat formatInt:(int)minutesDiff];
        return [NSString stringWithFormat:NSLocalizedString(@"DATE_MINUTES_AGO_FORMAT",
                                              @"Format string for a relative time, expressed as a certain number of "
                                              @"minutes in the past. Embeds {{The number of minutes}}."),
                         minutesString];
    } else {
        return [self formatDateAsTime:date];
    }
}

+ (BOOL)isTimestampRelative:(uint64_t)timestamp maxRelativeDurationMinutes:(NSInteger)maxRelativeDurationMinutes
{
    NSDate *date = [NSDate ows_dateWithMillisecondsSince1970:timestamp];
    NSDate *now = [NSDate new];

    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSInteger minutesDiff
        = MAX(0, [[calendar components:NSCalendarUnitMinute fromDate:date toDate:now options:0] minute]);

    return minutesDiff <= maxRelativeDurationMinutes;
}

+ (NSString *)exemplaryNowTimeFormat
{
    return NSLocalizedString(@"DATE_NOW", @"The present; the current time.");
}

+ (NSString *)exemplaryRelativeTimeFormatWithMaxRelativeDurationMinutes:(NSInteger)maxRelativeDurationMinutes
{
    NSString *minutesString = [OWSFormat formatInt:(int)maxRelativeDurationMinutes];
    return [NSString stringWithFormat:NSLocalizedString(@"DATE_MINUTES_AGO_FORMAT",
                                          @"Format string for a relative time, expressed as a certain number of "
                                          @"minutes in the past. Embeds {{The number of minutes}}."),
                     minutesString];
}

+ (BOOL)isSameDayWithTimestamp:(uint64_t)timestamp1 timestamp:(uint64_t)timestamp2
{
    return [self isSameDayWithDate:[NSDate ows_dateWithMillisecondsSince1970:timestamp1]
                              date:[NSDate ows_dateWithMillisecondsSince1970:timestamp2]];
}

+ (BOOL)isSameDayWithDate:(NSDate *)date1 date:(NSDate *)date2
{
    NSInteger dayDifference = [self daysFromFirstDate:date1 toSecondDate:date2];
    return dayDifference == 0;
}

@end

NS_ASSUME_NONNULL_END
