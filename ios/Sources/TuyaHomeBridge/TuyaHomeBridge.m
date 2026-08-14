#import "TuyaHomeBridge.h"

@interface ThingSmartHomeManager : NSObject
- (void)getHomeListWithSuccess:(void (^)(NSArray *homes))success
                       failure:(void (^)(NSError *error))failure;
- (void)addHomeWithName:(NSString *)name
                geoName:(NSString *)geoName
                  rooms:(NSArray<NSString *> *)rooms
               latitude:(double)latitude
              longitude:(double)longitude
                success:(void (^)(long long homeId))success
                failure:(void (^)(NSError *error))failure;
@end

@implementation TuyaHomeBridge

+ (void)getHomeListWithSuccess:(TuyaHomeBridgeSuccess)success
                       failure:(TuyaHomeBridgeFailure)failure {
  ThingSmartHomeManager *manager = [[ThingSmartHomeManager alloc] init];
  [manager getHomeListWithSuccess:^(NSArray *homes) {
    NSDictionary *result = [self resultWithHomes:homes source:@"query"];
    if (success) {
      success(result);
    }
  } failure:^(NSError *error) {
    [self emitFailure:failure fallback:@"Get home list failed" error:error];
  }];
}

+ (void)createHomeWithName:(NSString *)name
                   success:(TuyaHomeBridgeSuccess)success
                   failure:(TuyaHomeBridgeFailure)failure {
  NSString *cleanName = name.length > 0 ? name : @"默认家庭";
  ThingSmartHomeManager *manager = [[ThingSmartHomeManager alloc] init];
  [manager addHomeWithName:cleanName
                   geoName:@""
                     rooms:@[@"默认房间"]
                  latitude:0
                 longitude:0
                   success:^(long long homeId) {
    NSDictionary *home = @{
      @"homeId": @(homeId),
      @"name": cleanName,
      @"geoName": @"",
      @"lon": @0,
      @"lat": @0,
      @"deviceCount": @0
    };
    if (success) {
      success(@{@"home": home, @"homeId": @(homeId), @"source": @"create"});
    }
  } failure:^(NSError *error) {
    [self emitFailure:failure fallback:@"Create home failed" error:error];
  }];
}

+ (void)getOrCreateDefaultHomeWithName:(NSString *)name
                               success:(TuyaHomeBridgeSuccess)success
                               failure:(TuyaHomeBridgeFailure)failure {
  NSString *cleanName = name.length > 0 ? name : @"默认家庭";
  ThingSmartHomeManager *manager = [[ThingSmartHomeManager alloc] init];
  [manager getHomeListWithSuccess:^(NSArray *homes) {
    if (homes.count > 0) {
      NSDictionary *result = [self resultWithHomes:homes source:@"query"];
      if (success) {
        success(result);
      }
      return;
    }
    [self createHomeWithName:cleanName success:success failure:failure];
  } failure:^(NSError *error) {
    [self emitFailure:failure fallback:@"Get default home failed" error:error];
  }];
}

+ (NSDictionary *)resultWithHomes:(NSArray *)homes source:(NSString *)source {
  NSMutableArray *items = [NSMutableArray array];
  for (id home in homes) {
    [items addObject:[self dictionaryFromHome:home]];
  }
  NSNumber *homeId = @0;
  if (items.count > 0) {
    id firstId = items.firstObject[@"homeId"];
    if ([firstId isKindOfClass:NSNumber.class]) {
      homeId = firstId;
    }
  }
  return @{
    @"homes": items,
    @"count": @(items.count),
    @"homeId": homeId,
    @"source": source
  };
}

+ (NSDictionary *)dictionaryFromHome:(id)home {
  NSNumber *homeId = [self numberValue:[self safeValue:home key:@"homeId"]];
  NSString *name = [self stringValue:[self safeValue:home key:@"name"]];
  NSString *geoName = [self stringValue:[self safeValue:home key:@"geoName"]];
  NSNumber *lon = [self numberValue:[self safeValue:home key:@"lon"]];
  NSNumber *lat = [self numberValue:[self safeValue:home key:@"lat"]];
  NSArray *devices = [self safeValue:home key:@"deviceList"];
  return @{
    @"homeId": homeId,
    @"name": name,
    @"geoName": geoName,
    @"lon": lon,
    @"lat": lat,
    @"deviceCount": @([devices isKindOfClass:NSArray.class] ? devices.count : 0)
  };
}

+ (id)safeValue:(id)object key:(NSString *)key {
  @try {
    id value = [object valueForKey:key];
    return value == nil || value == NSNull.null ? nil : value;
  } @catch (__unused NSException *exception) {
    return nil;
  }
}

+ (NSNumber *)numberValue:(id)value {
  if ([value isKindOfClass:NSNumber.class]) {
    return value;
  }
  if ([value isKindOfClass:NSString.class]) {
    return @([(NSString *)value doubleValue]);
  }
  return @0;
}

+ (NSString *)stringValue:(id)value {
  if ([value isKindOfClass:NSString.class]) {
    return value;
  }
  if ([value respondsToSelector:@selector(stringValue)]) {
    return [value stringValue];
  }
  return @"";
}

+ (void)emitFailure:(TuyaHomeBridgeFailure)failure
           fallback:(NSString *)fallback
              error:(NSError *)error {
  if (!failure) {
    return;
  }
  NSInteger code = error ? error.code : -1;
  NSString *message = error.localizedDescription.length > 0
      ? [NSString stringWithFormat:@"%@: %@", fallback, error.localizedDescription]
      : fallback;
  failure(code, message);
}

@end
