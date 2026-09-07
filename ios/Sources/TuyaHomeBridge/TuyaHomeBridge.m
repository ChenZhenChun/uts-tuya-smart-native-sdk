#import "TuyaHomeBridge.h"
#import <objc/runtime.h>

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

@interface ThingSmartHome : NSObject
+ (instancetype)homeWithHomeId:(long long)homeId;
- (void)getHomeDataWithSuccess:(void (^)(id homeModel))success
                       failure:(void (^)(NSError *error))failure;
@property (nonatomic, strong, readonly) NSArray *deviceList;
@end

@interface ThingSmartDevice : NSObject
+ (instancetype)deviceWithDeviceId:(NSString *)deviceId;
@property (nonatomic, strong, readonly) id deviceModel;
@end

@interface ThingSmartBLEManager : NSObject
+ (instancetype)sharedInstance;
@property (nonatomic, strong, nullable) id delegate;
- (void)startListening:(BOOL)clearCache;
- (void)stopListening:(BOOL)clearCache;
@end

@interface ThingSmartBizCore : NSObject
+ (instancetype)sharedInstance;
- (void)registerService:(Protocol *)service withInstance:(id)instance;
- (id)serviceOfProtocol:(Protocol *)service;
- (void)updateConfig;
@end

@interface NSObject (TuyaPanelRuntime)
- (void)gotoPanelViewControllerWithDevice:(id)device
                                    group:(nullable id)group
                             initialProps:(nullable NSDictionary *)initialProps
                             contextProps:(nullable NSDictionary *)contextProps
                               completion:(nullable void (^)(NSError * _Nullable error))completion;
- (void)updateCurrentFamilyId:(long long)homeId;
@end

@interface TuyaFamilyProvider : NSObject
@property (nonatomic, strong, nullable) ThingSmartHome *home;
@property (nonatomic, assign) long long homeId;
@end

@implementation TuyaFamilyProvider
- (ThingSmartHome *)getCurrentHome {
  return self.home;
}
- (long long)currentFamilyId {
  return self.homeId;
}
- (void)updateCurrentFamilyId:(long long)homeId {
  self.homeId = homeId;
}
@end

@interface TuyaBLESearchProxy : NSObject
@property (nonatomic, copy) NSString *productId;
@property (nonatomic, copy, nullable) TuyaHomeBridgeSuccess success;
@property (nonatomic, copy, nullable) TuyaHomeBridgeFailure failure;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *foundDevices;
@property (nonatomic, assign) NSUInteger generation;
- (void)startWithProductId:(NSString *)productId
                   timeout:(NSTimeInterval)timeout
                   success:(TuyaHomeBridgeSuccess)success
                   failure:(TuyaHomeBridgeFailure)failure;
- (void)stopAndClear:(BOOL)clearCache;
@end

@implementation TuyaBLESearchProxy

- (instancetype)init {
  self = [super init];
  if (self) {
    _productId = @"";
    _foundDevices = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)startWithProductId:(NSString *)productId
                   timeout:(NSTimeInterval)timeout
                   success:(TuyaHomeBridgeSuccess)success
                   failure:(TuyaHomeBridgeFailure)failure {
  Class managerClass = NSClassFromString(@"ThingSmartBLEManager");
  if (!managerClass || ![managerClass respondsToSelector:@selector(sharedInstance)]) {
    if (failure) {
      failure(@(-300030), @"ThingSmartBLEManager is unavailable. Check ThingSmartHomeKit integration.");
    }
    return;
  }
  Protocol *delegateProtocol = NSProtocolFromString(@"ThingSmartBLEManagerDelegate");
  if (delegateProtocol) {
    class_addProtocol(self.class, delegateProtocol);
  }
  self.productId = productId ?: @"";
  self.success = success;
  self.failure = failure;
  [self.foundDevices removeAllObjects];
  self.generation += 1;
  NSUInteger currentGeneration = self.generation;
  ThingSmartBLEManager *manager = [managerClass sharedInstance];
  manager.delegate = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    [manager startListening:YES];
    [self emitEvent:@"searchStarted" searching:YES];
  });

  NSTimeInterval safeTimeout = timeout > 0 ? timeout : 120;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(safeTimeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if (self.generation != currentGeneration) {
      return;
    }
    [self stopAndClear:NO];
    [self emitEvent:@"searchTimeout" searching:NO];
  });
}

- (void)stopAndClear:(BOOL)clearCache {
  self.generation += 1;
  Class managerClass = NSClassFromString(@"ThingSmartBLEManager");
  if (managerClass && [managerClass respondsToSelector:@selector(sharedInstance)]) {
    ThingSmartBLEManager *manager = [managerClass sharedInstance];
    [manager stopListening:clearCache];
    manager.delegate = nil;
  }
}

- (void)bluetoothDidUpdateState:(BOOL)isPoweredOn {
  if (!isPoweredOn && self.failure) {
    self.failure(@(-300031), @"Bluetooth is powered off or permission was denied.");
  }
}

- (void)didDiscoveryDeviceWithDeviceInfo:(id)deviceInfo {
  NSString *uuid = [self textValue:[self safeValue:deviceInfo key:@"uuid"]];
  NSString *pid = [self textValue:[self safeValue:deviceInfo key:@"productId"]];
  if (pid.length == 0) {
    pid = [self textValue:[self safeValue:deviceInfo key:@"productKey"]];
  }
  if (uuid.length == 0) {
    return;
  }
  if (self.productId.length > 0 && ![self.productId isEqualToString:pid]) {
    return;
  }
  NSString *mac = [self textValue:[self safeValue:deviceInfo key:@"mac"]];
  NSDictionary *device = @{
    @"uuid": uuid,
    @"productId": pid,
    @"pid": pid,
    @"address": mac,
    @"mac": mac,
    @"name": [self textValue:[self safeValue:deviceInfo key:@"name"]],
    @"isActive": [self numberValue:[self safeValue:deviceInfo key:@"isActive"]],
    @"isSupport5G": [self numberValue:[self safeValue:deviceInfo key:@"isSupport5G"]],
    @"bleType": [self numberValue:[self safeValue:deviceInfo key:@"bleType"]]
  };
  self.foundDevices[uuid] = device;
  [self emitEvent:@"deviceFound" searching:YES];
}

- (void)emitEvent:(NSString *)event searching:(BOOL)searching {
  if (!self.success) {
    return;
  }
  NSArray *devices = self.foundDevices.allValues ?: @[];
  NSDictionary *result = @{
    @"event": event ?: @"search",
    @"searching": @(searching),
    @"platform": @"ios",
    @"mode": @"BLE_WIFI",
    @"devices": devices,
    @"count": @(devices.count)
  };
  NSData *data = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
  NSString *json = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"{}";
  self.success(json ?: @"{}");
}

- (id)safeValue:(id)object key:(NSString *)key {
  @try {
    id value = [object valueForKey:key];
    return value == nil || value == NSNull.null ? nil : value;
  } @catch (__unused NSException *exception) {
    return nil;
  }
}

- (NSString *)textValue:(id)value {
  if ([value isKindOfClass:NSString.class]) {
    return value;
  }
  if ([value respondsToSelector:@selector(stringValue)]) {
    return [value stringValue];
  }
  return @"";
}

- (NSNumber *)numberValue:(id)value {
  if ([value isKindOfClass:NSNumber.class]) {
    return value;
  }
  if ([value isKindOfClass:NSString.class]) {
    return @([(NSString *)value doubleValue]);
  }
  return @0;
}

@end

@implementation TuyaHomeBridge

static TuyaFamilyProvider *sFamilyProvider;
static TuyaBLESearchProxy *sBLESearchProxy;

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
      [self rememberFirstHome:homes];
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
      [self rememberHomeId:homeId];
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
        [self rememberFirstHome:homes];
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

+ (void)getDeviceListWithHomeId:(long long)homeId
                         success:(TuyaHomeBridgeSuccess)success
                         failure:(TuyaHomeBridgeFailure)failure {
  if (homeId <= 0) {
    [self emitMessageFailure:failure code:-300010 message:@"homeId cannot be empty"];
    return;
  }
  [self loadHomeId:homeId success:^(ThingSmartHome *home) {
    id deviceListValue = [self safeValue:home key:@"deviceList"];
    NSArray *devices = [deviceListValue isKindOfClass:NSArray.class] ? deviceListValue : @[];
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:devices.count];
    for (id device in devices) {
      [items addObject:[self dictionaryFromDevice:device]];
    }
    if (success) {
      success([self jsonStringWithObject:@{
        @"devices": items,
        @"count": @(items.count),
        @"homeId": @(homeId)
      }]);
    }
  } failure:failure];
}

+ (void)openDevicePanelWithDeviceId:(NSString *)deviceId
                             success:(TuyaHomeBridgeSuccess)success
                             failure:(TuyaHomeBridgeFailure)failure {
  NSString *cleanDeviceId = [deviceId stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (cleanDeviceId.length == 0) {
    [self emitMessageFailure:failure code:-300020 message:@"devId cannot be empty"];
    return;
  }

  @try {
    Class deviceClass = NSClassFromString(@"ThingSmartDevice");
    if (!deviceClass || ![deviceClass respondsToSelector:@selector(deviceWithDeviceId:)]) {
      [self emitMessageFailure:failure code:-300021 message:@"ThingSmartDevice is unavailable. Check ThingSmartHomeKit integration."];
      return;
    }
    ThingSmartDevice *device = [deviceClass deviceWithDeviceId:cleanDeviceId];
    id deviceModel = device.deviceModel;
    if (!deviceModel) {
      [self emitMessageFailure:failure code:-300022 message:@"Device model not found. Load the home device list before opening the panel."];
      return;
    }
    [self prepareBizBundleWithDeviceModel:deviceModel failure:failure completion:^{
      Class coreClass = NSClassFromString(@"ThingSmartBizCore");
      Protocol *panelProtocol = NSProtocolFromString(@"ThingPanelProtocol");
      if (!coreClass || !panelProtocol) {
        [self emitMessageFailure:failure code:-300023 message:@"Tuya Panel BizBundle is unavailable. Check ThingSmartPanelBizBundle and ThingSmartMiniAppBizBundle."];
        return;
      }
      ThingSmartBizCore *core = [coreClass sharedInstance];
      [core updateConfig];
      id panel = [core serviceOfProtocol:panelProtocol];
      SEL openSelector = @selector(gotoPanelViewControllerWithDevice:group:initialProps:contextProps:completion:);
      if (!panel || ![panel respondsToSelector:openSelector]) {
        [self emitMessageFailure:failure code:-300024 message:@"ThingPanelProtocol service is unavailable."];
        return;
      }
      dispatch_async(dispatch_get_main_queue(), ^{
        [panel gotoPanelViewControllerWithDevice:deviceModel
                                           group:nil
                                    initialProps:nil
                                    contextProps:nil
                                      completion:^(NSError *error) {
          if (error) {
            [self emitFailure:failure fallback:@"Open Tuya device panel failed" error:error];
          }
        }];
        if (success) {
          success([self jsonStringWithObject:@{
            @"opened": @YES,
            @"devId": cleanDeviceId,
            @"target": @"device-panel"
          }]);
        }
      });
    }];
  } @catch (NSException *exception) {
    [self emitException:failure fallback:@"Open Tuya device panel crashed" exception:exception];
  }
}

+ (void)startSearchToyDevicesWithProductId:(NSString *)productId
                                    timeout:(NSNumber *)timeout
                                    success:(TuyaHomeBridgeSuccess)success
                                    failure:(TuyaHomeBridgeFailure)failure {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sBLESearchProxy = [TuyaBLESearchProxy new];
  });
  [sBLESearchProxy startWithProductId:productId
                              timeout:timeout.doubleValue
                              success:success
                              failure:failure];
}

+ (void)stopSearchToyDevicesWithSuccess:(TuyaHomeBridgeSuccess)success
                                 failure:(__unused TuyaHomeBridgeFailure)failure {
  [sBLESearchProxy stopAndClear:YES];
  if (success) {
    success(@"{\"stopped\":true,\"target\":\"search\",\"platform\":\"ios\"}");
  }
}

+ (void)prepareBizBundleWithDeviceModel:(id)deviceModel
                                failure:(TuyaHomeBridgeFailure)failure
                             completion:(void (^)(void))completion {
  long long homeId = [[self numberValue:[self safeValue:deviceModel key:@"homeId"]] longLongValue];
  if (homeId <= 0 && sFamilyProvider.homeId > 0) {
    homeId = sFamilyProvider.homeId;
  }
  if (homeId <= 0) {
    [self emitMessageFailure:failure code:-300025 message:@"Device homeId is unavailable. Get the device list before opening the panel."];
    return;
  }
  if (sFamilyProvider.home && sFamilyProvider.homeId == homeId) {
    [self registerFamilyService];
    completion();
    return;
  }
  [self loadHomeId:homeId success:^(__unused ThingSmartHome *home) {
    [self registerFamilyService];
    completion();
  } failure:failure];
}

+ (void)loadHomeId:(long long)homeId
            success:(void (^)(ThingSmartHome *home))success
            failure:(TuyaHomeBridgeFailure)failure {
  Class homeClass = NSClassFromString(@"ThingSmartHome");
  if (!homeClass || ![homeClass respondsToSelector:@selector(homeWithHomeId:)]) {
    [self emitMessageFailure:failure code:-300011 message:@"ThingSmartHome is unavailable. Check ThingSmartHomeKit integration."];
    return;
  }
  ThingSmartHome *home = [homeClass homeWithHomeId:homeId];
  [home getHomeDataWithSuccess:^(__unused id homeModel) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self familyProvider].home = home;
      [self familyProvider].homeId = homeId;
      if (success) {
        success(home);
      }
    });
  } failure:^(NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self emitFailure:failure fallback:@"Get home detail failed" error:error];
    });
  }];
}

+ (TuyaFamilyProvider *)familyProvider {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sFamilyProvider = [TuyaFamilyProvider new];
  });
  return sFamilyProvider;
}

+ (void)registerFamilyService {
  Class coreClass = NSClassFromString(@"ThingSmartBizCore");
  Protocol *familyProtocol = NSProtocolFromString(@"ThingFamilyProtocol");
  if (!coreClass || !familyProtocol) {
    return;
  }
  class_addProtocol(TuyaFamilyProvider.class, familyProtocol);
  ThingSmartBizCore *core = [coreClass sharedInstance];
  [core registerService:familyProtocol withInstance:[self familyProvider]];
  id familyService = [core serviceOfProtocol:familyProtocol];
  if ([familyService respondsToSelector:@selector(updateCurrentFamilyId:)]) {
    [familyService updateCurrentFamilyId:sFamilyProvider.homeId];
  }
}

+ (void)rememberFirstHome:(NSArray *)homes {
  if (homes.count == 0) {
    return;
  }
  long long homeId = [[self numberValue:[self safeValue:homes.firstObject key:@"homeId"]] longLongValue];
  [self rememberHomeId:homeId];
}

+ (void)rememberHomeId:(long long)homeId {
  if (homeId > 0) {
    [self familyProvider].homeId = homeId;
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

+ (NSDictionary *)dictionaryFromDevice:(id)device {
  id dps = [self safeValue:device key:@"dps"];
  id schema = [self safeValue:device key:@"schema"];
  return @{
    @"devId": [self stringValue:[self safeValue:device key:@"devId"]],
    @"name": [self stringValue:[self safeValue:device key:@"name"]],
    @"productId": [self stringValue:[self safeValue:device key:@"productId"]],
    @"uuid": [self stringValue:[self safeValue:device key:@"uuid"]],
    @"category": [self stringValue:[self safeValue:device key:@"category"]],
    @"online": @([[self numberValue:[self safeValue:device key:@"isOnline"]] boolValue]),
    @"dpsText": [self jsonOrStringValue:dps],
    @"schemaText": [self jsonOrStringValue:schema]
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

+ (NSString *)jsonOrStringValue:(id)value {
  if (!value || value == NSNull.null) {
    return @"";
  }
  if ([value isKindOfClass:NSString.class]) {
    return value;
  }
  if ([NSJSONSerialization isValidJSONObject:value]) {
    return [self jsonStringWithObject:value];
  }
  return [value description] ?: @"";
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
