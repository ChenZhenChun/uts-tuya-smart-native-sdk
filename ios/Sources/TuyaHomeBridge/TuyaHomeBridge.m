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
  @try {
    ThingSmartHomeManager *manager = [self homeManagerWithFailure:failure];
    if (!manager) {
      return;
    }
    SEL selector = @selector(getHomeListWithSuccess:failure:);
    if (![manager respondsToSelector:selector]) {
      [self emitMessageFailure:failure code:-300002 message:@"ThingSmartHomeManager missing getHomeListWithSuccess:failure:"];
      return;
    }
    [manager getHomeListWithSuccess:^(NSArray *homes) {
      NSDictionary *result = [self resultWithHomes:homes source:@"query"];
      if (success) {
        success([self jsonStringWithObject:result]);
      }
    } failure:^(NSError *error) {
      [self emitFailure:failure fallback:@"Get home list failed" error:error];
    }];
  } @catch (NSException *exception) {
    [self emitException:failure fallback:@"Get home list crashed" exception:exception];
  }
}

+ (void)createHomeWithName:(NSString *)name
                   success:(TuyaHomeBridgeSuccess)success
                   failure:(TuyaHomeBridgeFailure)failure {
  @try {
    NSString *cleanName = name.length > 0 ? name : @"默认家庭";
    ThingSmartHomeManager *manager = [self homeManagerWithFailure:failure];
    if (!manager) {
      return;
    }
    SEL selector = @selector(addHomeWithName:geoName:rooms:latitude:longitude:success:failure:);
    if (![manager respondsToSelector:selector]) {
      [self emitMessageFailure:failure code:-300003 message:@"ThingSmartHomeManager missing addHomeWithName:geoName:rooms:latitude:longitude:success:failure:"];
      return;
    }
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
        success([self jsonStringWithObject:@{@"home": home, @"homeId": @(homeId), @"source": @"create"}]);
      }
    } failure:^(NSError *error) {
      [self emitFailure:failure fallback:@"Create home failed" error:error];
    }];
  } @catch (NSException *exception) {
    [self emitException:failure fallback:@"Create home crashed" exception:exception];
  }
}

+ (void)getOrCreateDefaultHomeWithName:(NSString *)name
                               success:(TuyaHomeBridgeSuccess)success
                               failure:(TuyaHomeBridgeFailure)failure {
  @try {
    NSString *cleanName = name.length > 0 ? name : @"默认家庭";
    ThingSmartHomeManager *manager = [self homeManagerWithFailure:failure];
    if (!manager) {
      return;
    }
    SEL selector = @selector(getHomeListWithSuccess:failure:);
    if (![manager respondsToSelector:selector]) {
      [self emitMessageFailure:failure code:-300002 message:@"ThingSmartHomeManager missing getHomeListWithSuccess:failure:"];
      return;
    }
    [manager getHomeListWithSuccess:^(NSArray *homes) {
      if (homes.count > 0) {
        NSDictionary *result = [self resultWithHomes:homes source:@"query"];
        if (success) {
          success([self jsonStringWithObject:result]);
        }
        return;
      }
      [self createHomeWithName:cleanName success:success failure:failure];
    } failure:^(NSError *error) {
      [self emitFailure:failure fallback:@"Get default home failed" error:error];
    }];
  } @catch (NSException *exception) {
    [self emitException:failure fallback:@"Get or create home crashed" exception:exception];
  }
}

+ (ThingSmartHomeManager *)homeManagerWithFailure:(TuyaHomeBridgeFailure)failure {
  Class managerClass = NSClassFromString(@"ThingSmartHomeManager");
  if (!managerClass) {
    [self emitMessageFailure:failure code:-300001 message:@"ThingSmartHomeManager class not found. Check ThingSmartHomeKit integration."];
    return nil;
  }
  id manager = [[managerClass alloc] init];
  if (![manager isKindOfClass:managerClass]) {
    [self emitMessageFailure:failure code:-300004 message:@"ThingSmartHomeManager init failed."];
    return nil;
  }
  return manager;
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

+ (NSString *)jsonStringWithObject:(id)object {
  if (!object) {
    return @"{}";
  }
  @try {
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
    if (!data) {
      return @"{}";
    }
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return json.length > 0 ? json : @"{}";
  } @catch (__unused NSException *exception) {
    return @"{}";
  }
}

+ (void)emitFailure:(TuyaHomeBridgeFailure)failure
           fallback:(NSString *)fallback
              error:(NSError *)error {
  if (!failure) {
    return;
  }
  NSNumber *code = @(error ? error.code : -1);
  NSString *message = error.localizedDescription.length > 0
      ? [NSString stringWithFormat:@"%@: %@", fallback, error.localizedDescription]
      : fallback;
  failure(code, message);
}

+ (void)emitException:(TuyaHomeBridgeFailure)failure
             fallback:(NSString *)fallback
            exception:(NSException *)exception {
  NSString *message = [NSString stringWithFormat:@"%@: %@ %@", fallback, exception.name ?: @"NSException", exception.reason ?: @""];
  [self emitMessageFailure:failure code:-300099 message:message];
}

+ (void)emitMessageFailure:(TuyaHomeBridgeFailure)failure
                      code:(NSInteger)code
                   message:(NSString *)message {
  if (failure) {
    failure(@(code), message ?: @"TuyaHomeBridge failed");
  }
}

@end
