#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^TuyaHomeBridgeSuccess)(id result);
typedef void (^TuyaHomeBridgeFailure)(NSNumber *code, NSString *message);

@interface TuyaHomeBridge : NSObject

+ (void)getHomeListWithSuccess:(TuyaHomeBridgeSuccess)success
                       failure:(TuyaHomeBridgeFailure)failure
    NS_SWIFT_NAME(getHomeList(success:failure:));

+ (void)createHomeWithName:(NSString *)name
                   success:(TuyaHomeBridgeSuccess)success
                   failure:(TuyaHomeBridgeFailure)failure
    NS_SWIFT_NAME(createHome(name:success:failure:));

+ (void)getOrCreateDefaultHomeWithName:(NSString *)name
                               success:(TuyaHomeBridgeSuccess)success
                               failure:(TuyaHomeBridgeFailure)failure
    NS_SWIFT_NAME(getOrCreateDefaultHome(name:success:failure:));

+ (void)getDeviceListWithHomeId:(long long)homeId
                         success:(TuyaHomeBridgeSuccess)success
                         failure:(TuyaHomeBridgeFailure)failure
    NS_SWIFT_NAME(getDeviceList(homeId:success:failure:));

+ (void)openDevicePanelWithDeviceId:(NSString *)deviceId
                             success:(TuyaHomeBridgeSuccess)success
                             failure:(TuyaHomeBridgeFailure)failure
    NS_SWIFT_NAME(openDevicePanel(deviceId:success:failure:));

@end

NS_ASSUME_NONNULL_END
