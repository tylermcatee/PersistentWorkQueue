//
//  PersistentWorkQueue.h
//  PersistentWorkQueue
//
//  Created by Tyler McAtee on 5/21/15.
//  Copyright (c) 2015 McAtee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface PersistentWorkQueue : NSObject

@property (nonatomic, readonly) NSManagedObjectContext *context;

+(instancetype)queueWithManagedObjectContext:(NSManagedObjectContext *)context;
-(void)enqueueNewObjectForEntityName:(NSString *)entityName withProperties:(NSDictionary *)properties;
-(id)dequeueObjectForEntityName:(NSString *)entityName;
-(NSArray *)dequeueObjectsForEntityName:(NSString *)entityName numberOfObjects:(NSInteger)numberOfObjects;
-(void)releaseObjectFromStorage:(NSManagedObject *)object;

@end
