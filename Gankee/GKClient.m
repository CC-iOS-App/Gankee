//
//  GKAPIManager.m
//  Gankee
//
//  Created by Wildog on 1/23/17.
//  Copyright © 2017 Wildog. All rights reserved.
//

#import "GKClient.h"
#import "GKItem.h"

#define BASE_URL @"https://gank.io/api/"

@interface GKClient ()

@property (nonatomic, strong) NSDictionary *mapping;
@property (nonatomic, strong) NSURLSession *session;

@end

@implementation GKClient

- (instancetype)init
{
    self = [super init];
    if (self) {
        _mapping = @{@(GKCategoryAll): @"all",
                     @(GKCategoryIOS): @"iOS",
                     @(GKCategoryAndroid): @"Android",
                     @(GKCategoryApp): @"App",
                     @(GKCategoryFrontend): @"前端",
                     @(GKCategoryExplore): @"瞎推荐",
                     @(GKCategoryExt): @"拓展资源",
                     @(GKCategoryVideo): @"休息视频",
                     @(GKCategoryWelfare): @"福利"};
        NSString *userAgent = [NSString stringWithFormat:@"Gankee/%@, iOS/%@",
                               [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],
                               [[NSProcessInfo processInfo] operatingSystemVersionString]];
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        _session.configuration.HTTPAdditionalHeaders = @{@"User-Agent": userAgent};
    }
    return self;
}

+ (instancetype)client {
    static GKClient *client = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        client = [[GKClient alloc] init];
    });
    return client;
}

- (RACSignal *)dataForCategory:(GKCategory)category
                 onPage:(NSUInteger)page
              withCount:(NSUInteger)count
               onSearch:(NSString *)search
              randomize:(BOOL)randomize {
    return [[RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
        NSString *urlString = nil;
        
        if (!search) {
            NSString *ifRandom = randomize ? @"random/": @"";
            NSString *ifPage = randomize ? @"" : [NSString stringWithFormat:@"/%lu", (unsigned long)page];
            urlString = [NSString stringWithFormat:@"%@%@data/%@/%lu%@",
                         BASE_URL, ifRandom, _mapping[@(category)], (unsigned long)count, ifPage];
        } else {
            urlString = [NSString stringWithFormat:@"%@search/query/%@/category/%@/count/%lu/page/%lu",
                         BASE_URL, search, _mapping[@(category)], (unsigned long)count, (unsigned long)page];
        }
        
        NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
        NSURLSessionDataTask *task = [_session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error) {
                [subscriber sendError:error];
            } else {
                NSError *parseError;
                NSDictionary *resp = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&parseError];
                
                if (parseError) {
                    [subscriber sendError:parseError];
                } else {
                    NSDictionary *results = resp[@"results"];
                    NSMutableArray<GKItem *> *items = [NSMutableArray arrayWithCapacity:count];
                    
                    for (NSMutableDictionary *itemInfo in results) {
                        if (itemInfo[@"who"] == [NSNull null]) {
                            itemInfo[@"who"] = @"互联网";
                        }
                        if (itemInfo[@"type"] == [NSNull null]) {
                            itemInfo[@"type"] = @"未知分类";
                        }
                        // gank.io really has lots of messy non-standart time format
                        if (itemInfo[@"createdAt"] != [NSNull null]) {
                            NSString *created = itemInfo[@"createdAt"];
                            NSRange range = [created rangeOfString:@"." options:NSBackwardsSearch];
                            if (range.location != NSNotFound) {
                                itemInfo[@"createdAt"] = [created substringToIndex:range.location];
                            }
                        }
                        if (itemInfo[@"publishedAt"] != [NSNull null]) {
                            NSString *published = itemInfo[@"publishedAt"];
                            NSRange range = [published rangeOfString:@"." options:NSBackwardsSearch];
                            if (range.location != NSNotFound) {
                                itemInfo[@"publishedAt"] = [published substringToIndex:range.location];
                            }
                        }
                        GKItem *item = [GKItem yy_modelWithDictionary:itemInfo];
                        [items addObject:item];
                    }
                    
                    [subscriber sendNext:items];
                    [subscriber sendCompleted];
                }
            }
        }];
        [task resume];
        return nil;
    }] logError];
}

- (RACSignal *)dataForDay:(NSString *)day {
    return [[RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
        NSString *dayParams = [day stringByReplacingOccurrencesOfString:@"-" withString:@"/"];
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@day/%@", BASE_URL, dayParams]];
        NSURLSessionDataTask *task = [_session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
            if (error) {
                [subscriber sendError:error];
            } else {
                NSError *parseError;
                NSDictionary *resp = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&parseError];
                
                if (parseError) {
                    [subscriber sendError:parseError];
                } else {
                    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
                    dict[@"categories"] = resp[@"category"];
                    
                    NSDictionary *results = resp[@"results"];
                    for (NSString *categoryKey in results) {
                        NSMutableArray<GKItem *> *items = [NSMutableArray arrayWithCapacity:5];
                        for (NSMutableDictionary *itemInfo in results[categoryKey]) {
                            if (itemInfo[@"who"] == [NSNull null]) {
                                itemInfo[@"who"] = @"互联网";
                            }
                            if (itemInfo[@"type"] == [NSNull null]) {
                                itemInfo[@"type"] = @"未知分类";
                            }
                            // gank.io really has lots of messy non-standart time format
                            if (itemInfo[@"createdAt"] != [NSNull null]) {
                                NSString *created = itemInfo[@"createdAt"];
                                NSRange range = [created rangeOfString:@"." options:NSBackwardsSearch];
                                if (range.location != NSNotFound) {
                                    itemInfo[@"createdAt"] = [created substringToIndex:range.location];
                                }
                            }
                            if (itemInfo[@"publishedAt"] != [NSNull null]) {
                                NSString *published = itemInfo[@"publishedAt"];
                                NSRange range = [published rangeOfString:@"." options:NSBackwardsSearch];
                                if (range.location != NSNotFound) {
                                    itemInfo[@"publishedAt"] = [published substringToIndex:range.location];
                                }
                            }
                            GKItem *item = [GKItem yy_modelWithDictionary:itemInfo];
                            [items addObject:item];
                        }
                        dict[categoryKey] = items;
                    }
                    
                    [subscriber sendNext:dict];
                    [subscriber sendCompleted];
                }
            }
        }];
        [task resume];
        return nil;
    }] logError];
}

- (RACSignal *)availableDays {
    return [[RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@day/history", BASE_URL]];
        NSURLSessionDataTask *task = [_session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error) {
                [subscriber sendError:error];
            } else {
                NSError *parseError;
                NSDictionary *resp = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&parseError];
            
                if (parseError) {
                    [subscriber sendError:parseError];
                } else {
                    [subscriber sendNext:resp[@"results"]];
                    [subscriber sendCompleted];
                }
            }
        }];
        [task resume];
        return nil;
    }] logError];
}


@end
