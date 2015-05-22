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

/*!
 @method        sharedQueueWithManagedObjectContext:
 @abstract      Generates a single instance of the PersistentWorkQueue for the application.
 */
+(instancetype)sharedQueueWithmanagedObjectContext:(NSManagedObjectContext *)context;

/*!
 @method        enqueueNewObjectForEntityName:withProperties:
 @param         entityName the name of an entity defined in the xcdatamodel
 @param         properties a dictionary of properties that will be set on the entity.
 @abstract      Inserts an entity into the work queue and notifies any sleeping threads that
                it has a waiting entity.
 @discussion    Does not catch errors that might be thrown if entity doesn't exist, or properties
                passed in do not exist on the entity.
*/
-(void)enqueueNewObjectForEntityName:(NSString *)entityName withProperties:(NSDictionary *)properties;

/*!
 @method        dequeueObjectForEntityName:
 @param         entityName the name of an entity defined in the xcdatamodel
 @abstract      Tries to get an entity from the work queue. If queue is empty the thread will sleep
                until an entity is available.
 @discussion    Does not remove the entity from the storage, but 'blacklists' it so it will not be pulled
                again during the lifecycle of the program. Use releaseObjectFromStorage: to release the object.
*/
-(id)dequeueObjectForEntityName:(NSString *)entityName;

/*!
 @method        dequeueObjectsForEntityName:numberOfObjects:
 @param         entityName the name of an entity defined in the xcdatamodel
 @param         numberOfObjects the number of entities to return
 @abstract      Tries to get an entity from the work queue. If queue is empty the thread will sleep
 until an entity is available.
 @discussion    Does not remove the entity from the storage, but 'blacklists' it so it will not be pulled
 again during the lifecycle of the program. Use releaseObjectFromStorage: to release the object.
 */
-(NSArray *)dequeueObjectsForEntityName:(NSString *)entityName numberOfObjects:(NSInteger)numberOfObjects;

/*!
 @method        releaseObjectFromStorage:
 @param         object an NSMangedObject that has been output from the queue
 @abstract      Releases the object from the persistent store
 */
-(void)releaseObjectFromStorage:(NSManagedObject *)object;

@end
