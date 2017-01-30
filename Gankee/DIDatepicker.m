//
//  Created by Dmitry Ivanenko on 14.04.14.
//  Copyright (c) 2014 Dmitry Ivanenko. All rights reserved.
//

#import "DIDatepicker.h"
#import "DIDatepickerDateView.h"

const CGFloat kDIDatepickerHeight = 60.;
const CGFloat kDIDatepickerSpaceBetweenItems = 15.;
NSString * const kDIDatepickerCellIndentifier = @"kDIDatepickerCellIndentifier";

@interface DIDatepicker (){
    NSIndexPath *selectedIndexPath;
}

@property (strong, nonatomic) UICollectionView *datesCollectionView;
@property (strong, nonatomic, readwrite) NSDate *selectedDate;

@end


@implementation DIDatepicker

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self setupViews];
}

- (id)initWithFrame:(CGRect)frame
{
    if(self = [super initWithFrame:frame]){
        [self setupViews];
    }
    
    return self;
}

- (void)setupViews
{
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.backgroundColor = [UIColor whiteColor];
    self.bottomLineColor = [UIColor colorWithWhite:0.816 alpha:1.000];
    self.selectedDateBottomLineColor = self.tintColor;
    self.displayed = NO;
}

#pragma mark Setters | Getters

- (void)setDates:(NSArray *)dates
{
    _dates = dates;
    
    [self.datesCollectionView reloadData];
    
    //self.selectedDate = _selectedDate;
}

- (void)setSelectedDate:(NSDate *)selectedDate
{
    _selectedDate = selectedDate;
    
    NSIndexPath *selectedCellIndexPath = [NSIndexPath indexPathForItem:[self.dates indexOfObject:selectedDate] inSection:0];
    [self.datesCollectionView deselectItemAtIndexPath:selectedIndexPath animated:NO];
    [self.datesCollectionView selectItemAtIndexPath:selectedCellIndexPath animated:NO scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
    selectedIndexPath = selectedCellIndexPath;
    
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (UICollectionView *)datesCollectionView
{
    if (!_datesCollectionView) {
        UICollectionViewFlowLayout *collectionViewLayout = [[UICollectionViewFlowLayout alloc] init];
        [collectionViewLayout setItemSize:CGSizeMake(kDIDatepickerItemWidth, CGRectGetHeight(self.bounds))];
        [collectionViewLayout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
        [collectionViewLayout setSectionInset:UIEdgeInsetsMake(0, kDIDatepickerSpaceBetweenItems, 0, kDIDatepickerSpaceBetweenItems)];
        [collectionViewLayout setMinimumLineSpacing:kDIDatepickerSpaceBetweenItems];
        
        _datesCollectionView = [[UICollectionView alloc] initWithFrame:self.bounds collectionViewLayout:collectionViewLayout];
        [_datesCollectionView registerClass:[DIDatepickerCell class] forCellWithReuseIdentifier:kDIDatepickerCellIndentifier];
        [_datesCollectionView setBackgroundColor:[UIColor clearColor]];
        [_datesCollectionView setShowsHorizontalScrollIndicator:NO];
        [_datesCollectionView setAllowsMultipleSelection:NO];
        _datesCollectionView.dataSource = self;
        _datesCollectionView.delegate = self;
        [self addSubview:_datesCollectionView];
    }
    return _datesCollectionView;
}

- (void)setSelectedDateBottomLineColor:(UIColor *)selectedDateBottomLineColor
{
    _selectedDateBottomLineColor = selectedDateBottomLineColor;
    
    [self.datesCollectionView.indexPathsForSelectedItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        DIDatepickerCell *selectedCell = (DIDatepickerCell *)[self.datesCollectionView cellForItemAtIndexPath:obj];
        selectedCell.itemSelectionColor = _selectedDateBottomLineColor;
    }];
}

#pragma mark Public methods

- (void)selectDate:(NSDate *)date
{
    [[NSCalendar currentCalendar] rangeOfUnit:NSCalendarUnitDay startDate:&date interval:NULL forDate:date];
    
    NSAssert([self.dates indexOfObject:date] != NSNotFound, @"Date not found in dates array");
    
    self.selectedDate = date;
}

- (void)selectDateFromString:(NSString *)string {
    NSDate *date = [[self dateFormatter] dateFromString:string];
    _selectedDate = date;
}

- (void)selectDateAtIndex:(NSUInteger)index
{
    NSAssert(index < self.dates.count, @"Index too big");
    
    self.selectedDate = self.dates[index];
}

// -

- (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd"];
    });
    return formatter;
}

- (void)fillDatesFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate
{
    NSAssert([fromDate compare:toDate] == NSOrderedAscending, @"toDate must be after fromDate");
    
    NSMutableArray *dates = [[NSMutableArray alloc] init];
    NSDateComponents *days = [[NSDateComponents alloc] init];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSInteger dayCount = 0;
    while(YES){
        [days setDay:dayCount++];
        NSDate *date = [calendar dateByAddingComponents:days toDate:fromDate options:0];
        
        if([date compare:toDate] == NSOrderedDescending) break;
        [dates addObject:date];
    }
    
    self.dates = dates;
}

- (void)fillDatesFromArray:(NSArray *)array {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSMutableArray *dates = [[NSMutableArray alloc] initWithCapacity:array.count];
        
        for (NSString *dateString in array) {
            NSDate *date = [[self dateFormatter] dateFromString:dateString];
            [dates addObject:date];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.dates = dates;
            NSUInteger index = [self.dates indexOfObject:_selectedDate];
            NSIndexPath *selectedCellIndexPath = [NSIndexPath indexPathForItem:index inSection:0];
            [self.datesCollectionView deselectItemAtIndexPath:selectedIndexPath animated:NO];
            [self.datesCollectionView selectItemAtIndexPath:selectedCellIndexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
            selectedIndexPath = selectedCellIndexPath;
        });
    });
}

- (void)fillDatesFromDate:(NSDate *)fromDate numberOfDays:(NSInteger)numberOfDays
{
    NSDateComponents *days = [[NSDateComponents alloc] init];
    [days setDay:numberOfDays];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    [self fillDatesFromDate:fromDate toDate:[calendar dateByAddingComponents:days toDate:fromDate options:0]];
}

- (void)fillCurrentWeek
{
    NSDate *today = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *weekdayComponents = [calendar components:NSCalendarUnitWeekday fromDate:today];
    
    NSDateComponents *componentsToSubtract = [[NSDateComponents alloc] init];
    [componentsToSubtract setDay: - ((([weekdayComponents weekday] - [calendar firstWeekday]) + 7 ) % 7)];
    NSDate *beginningOfWeek = [calendar dateByAddingComponents:componentsToSubtract toDate:today options:0];
    
    NSDateComponents *componentsToAdd = [[NSDateComponents alloc] init];
    [componentsToAdd setDay:6];
    NSDate *endOfWeek = [calendar dateByAddingComponents:componentsToAdd toDate:beginningOfWeek options:0];
    
    [self fillDatesFromDate:beginningOfWeek toDate:endOfWeek];
}

- (void)fillCurrentMonth
{
    [self fillDatesWithCalendarUnit:NSCalendarUnitMonth];
}

- (void)fillCurrentYear
{
    [self fillDatesWithCalendarUnit:NSCalendarUnitYear];
}

#pragma mark Private methods

- (void)fillDatesWithCalendarUnit:(NSCalendarUnit)unit
{
    NSDate *today = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSDate *beginning;
    NSTimeInterval length;
    [calendar rangeOfUnit:unit startDate:&beginning interval:&length forDate:today];
    NSDate *end = [beginning dateByAddingTimeInterval:length-1];
    
    [self fillDatesFromDate:beginning toDate:end];
}

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    // draw bottom line
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, self.bottomLineColor.CGColor);
    CGContextSetLineWidth(context, .5);
    CGContextMoveToPoint(context, 0, rect.size.height - .5);
    CGContextAddLineToPoint(context, rect.size.width, rect.size.height - .5);
    CGContextStrokePath(context);
}

#pragma mark - UICollectionView Delegate

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return  [self.dates count];
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    DIDatepickerCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kDIDatepickerCellIndentifier forIndexPath:indexPath];
    cell.date = [self.dates objectAtIndex:indexPath.item];
    cell.itemSelectionColor = _selectedDateBottomLineColor;
    return cell;
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    return ![indexPath isEqual:selectedIndexPath];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [self.datesCollectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:YES];
    _selectedDate = [self.dates objectAtIndex:indexPath.item];
    
    [collectionView deselectItemAtIndexPath:selectedIndexPath animated:NO];
    selectedIndexPath = indexPath;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}


@end
