//
//  PersistentWorkQueue.m
//  PersistentWorkQueue
//
//  Created by Tyler McAtee on 5/21/15.
//  Copyright (c) 2015 McAtee. All rights reserved.
//

#import "PersistentWorkQueue.h"

@interface NSMutableArray (PersistentWorkQueue)
- (id)dequeue;
- (void)enqueue:(id)obj;
@end
@implementation NSMutableArray (PersistentWorkQueue)
-(id)dequeue {
    id headObject = [self objectAtIndex:0];
    if (headObject != nil) {
        [self removeObjectAtIndex:0];
    }
    return headObject;
}
-(void)enqueue:(id)anObject {
    [self addObject:anObject];
}
@end

@interface PersistentWorkQueue()

@property (atomic, assign) NSManagedObjectContext *context;
@property (atomic, strong) NSMutableArray *internalQueue;

@property (nonatomic) dispatch_queue_t writeQueue;
@property (nonatomic) dispatch_queue_t readQueue;

// Blacklisted objects are objects that cannot be returned from a dequeue
@property (atomic, strong) NSMutableArray *blacklist;

// Synchronization Primitives
@property (atomic, strong) NSMutableDictionary *conditionDictionary;

@end

@implementation PersistentWorkQueue

#pragma mark - Initialization

+(instancetype)sharedQueueWithmanagedObjectContext:(NSManagedObjectContext *)context {
    static PersistentWorkQueue *pQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pQueue = [[PersistentWorkQueue alloc] init];
        pQueue.context = context;
    });
    return pQueue;
}

+(instancetype)queueWithManagedObjectContext:(NSManagedObjectContext *)context {
    PersistentWorkQueue *pQueue = [[PersistentWorkQueue alloc] init];
    pQueue.context = context;
    return pQueue;
}

-(instancetype)init {
    if (self = [super init]) {
        // Initialize our properties
        self.internalQueue = [NSMutableArray array];
        self.writeQueue = dispatch_queue_create("com.mcatee.persistentWorkQueue.writeQueue", DISPATCH_QUEUE_SERIAL);
        self.readQueue = dispatch_queue_create("com.mcatee.persistentWorkQueue.readQueue", DISPATCH_QUEUE_SERIAL);
        self.blacklist = [NSMutableArray array];
        self.conditionDictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - condition variable management

-(NSCondition *)conditionForEntityName:(NSString *)entityName {
    if ([self.conditionDictionary objectForKey:entityName]) {
        return [self.conditionDictionary objectForKey:entityName];
    } else {
        NSCondition *newCondition = [[NSCondition alloc] init];
        [self.conditionDictionary setObject:newCondition forKey:entityName];
        return newCondition;
    }
}

#pragma mark - Save

-(void)save {
    [self.context save:nil];
}

#pragma mark - Inserting / Removing from work queue

-(void)enqueueNewObjectForEntityName:(NSString *)entityName withProperties:(NSDictionary *)properties {
    dispatch_async(self.writeQueue, ^{
        [self _enqueueNewObjectForEntityName:entityName withProperties:properties];
    });
}

-(void)_enqueueNewObjectForEntityName:(NSString *)entityName withProperties:(NSDictionary *)properties {
    // Lock the condition variable here
    NSCondition *condition = [self conditionForEntityName:entityName];
    [condition lock];
    // Create the object
    NSManagedObject *newEntity = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:self.context];
    // Populate its values
    [newEntity setValuesForKeysWithDictionary:properties];
    // Save to store
    [self save];
    // Signal the condition variable and unlock it.
    [condition signal];
    [condition unlock];
}

-(id)dequeueObjectForEntityName:(NSString *)entityName {
    return [[self dequeueObjectsForEntityName:entityName numberOfObjects:1] firstObject];
}

-(NSArray *)dequeueObjectsForEntityName:(NSString *)entityName numberOfObjects:(NSInteger)numberOfObjects {
    NSAssert(numberOfObjects > 0, @"Need number of objects to fetch greater than 0");
    __block NSArray *results;
    dispatch_sync(self.readQueue, ^{
        NSLog(@"calling _dequeue");
        results = [self _dequeueObjectsForEntityName:entityName numberOfObjects:numberOfObjects];
        NSLog(@"Returning with results = %@", results);
    });
    return results;
}

-(NSArray *)_dequeueObjectsForEntityName:(NSString *)entityName numberOfObjects:(NSInteger)numberOfObjects {
    // Make the fetch request for obtaining 1 object with entityName
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:entityName];
    fetchRequest.fetchLimit = numberOfObjects;
    NSPredicate *blacklistPredicate = [NSPredicate predicateWithFormat:@"NOT (self IN %@)", self.blacklist];
    fetchRequest.predicate = blacklistPredicate;
    
    // Lock the condition variable here
    NSCondition *condition = [self conditionForEntityName:entityName];
    [condition lock];
    
    // Perform the fetch
    NSArray *fetchResults = [self.context executeFetchRequest:fetchRequest error:nil];
    while (fetchResults.count < numberOfObjects) {
        [condition wait];
        fetchResults = [self.context executeFetchRequest:fetchRequest error:nil];
    }
    
    for (id managedObject in fetchResults) {
        // Put these objects into the black list so they will not be returned until released.
        [self.blacklist addObject:managedObject];
    }
    
    // Unlock the condition variable and return the fetched result
    [condition unlock];
    return fetchResults;
}

-(void)releaseObjectFromStorage:(NSManagedObject *)object {
    [self.context deleteObject:object];
}

@end
