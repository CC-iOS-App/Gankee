//
//  GKFavoriteViewController.m
//  Gankee
//
//  Created by Wildog on 1/31/17.
//  Copyright © 2017 Wildog. All rights reserved.
//

#import "GKFavoriteViewController.h"
#import "GKFavoriteItem+CoreDataClass.h"
#import "GKSafariViewController.h"

@interface GKFavoriteViewController () <UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) IBOutlet UIView *titleView;
@property (strong, nonatomic) IBOutlet UIButton *settingButton;

@property (strong, nonatomic) UISearchController *searchController;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;

@end

@implementation GKFavoriteViewController

#pragma mark Lazy Init

- (NSFetchedResultsController *)fetchedResultsController {
    if (!_fetchedResultsController) {
        _fetchedResultsController = [GKFavoriteItem MR_fetchAllSortedBy:@"added" ascending:NO withPredicate:nil groupBy:nil delegate:self];
    }
    return _fetchedResultsController;
}

- (NSDateFormatter *)dateFormatter {
    if (!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"M-d"];
    }
    return _dateFormatter;
}

#pragma mark Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.navigationItem.titleView = self.titleView;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.settingButton];
    
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"搜索本地收藏";
    self.searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 80;
    self.tableView.tableHeaderView = self.searchController.searchBar;
    self.tableView.tableFooterView = [UIView new];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    [NSFetchedResultsController deleteCacheWithName:nil];
    NSError *error;
    if (![self.fetchedResultsController performFetch:&error]) {
        NSLog(@"Unresolved error: %@", error);
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self check3DTouch];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark TableView DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.fetchedResultsController.sections[section] numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"result_cell_with_tag" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    UIView *bgView = [[UIView alloc] init];
    bgView.backgroundColor = [UIColor colorWithRed:0.92 green:0.92 blue:0.94 alpha:1];
    cell.selectedBackgroundView = bgView;
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    GKFavoriteItem *item = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    UILabel *descLabel = (UILabel *)[cell viewWithTag:1];
    UILabel *authorLabel = (UILabel *)[cell viewWithTag:2];
    UILabel *timeLabel = (UILabel *)[cell viewWithTag:3];
    UILabel *categoryLabel = (UILabel *)[cell viewWithTag:4];
    
    [descLabel setText:item.desc];
    [authorLabel setText:item.author];
    [categoryLabel setText:item.category];
    if (!item.created) {
        [timeLabel setText:@"未知日期"];
    } else {
        [timeLabel setText:[self.dateFormatter stringFromDate:item.created]];
    }
}

#pragma mark FetchedResultsController Delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    
    UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath]
                    atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

#pragma mark TableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    GKSafariViewController *viewController = [[GKSafariViewController alloc] initWithFavoriteItem:[self.fetchedResultsController objectAtIndexPath:indexPath]];
    [self presentViewController:viewController animated:YES completion:nil];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        GKFavoriteItem *item = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
            GKFavoriteItem *localItem = [item MR_inContext:localContext];
            [localItem MR_deleteEntity];
        }];
    }
}

#pragma mark Previewing Delegate

- (void)check3DTouch {
    // register for 3d touch if available
    if (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable) {
        [self registerForPreviewingWithDelegate:(id)self sourceView:self.view];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    // 3d touch availability changed
    [self check3DTouch];
}

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    if ([self.presentationController isKindOfClass:[GKSafariViewController class]]) {
        return nil;
    }
    
    CGPoint cellPosition = [self.tableView convertPoint:location fromView:self.view];
    NSIndexPath *path = [self.tableView indexPathForRowAtPoint:cellPosition];
    
    if (path) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:path];
        previewingContext.sourceRect = [self.view convertRect:cell.frame fromView:self.tableView];
        
        GKSafariViewController *viewController = [[GKSafariViewController alloc] initWithFavoriteItem:[self.fetchedResultsController objectAtIndexPath:path]];
        
        return viewController;
    }
    return nil;
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit {
    [self presentViewController:viewControllerToCommit animated:YES completion:nil];
}

@end
