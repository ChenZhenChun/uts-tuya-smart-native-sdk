#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^TuyaHomeBridgeSuccess)(NSDictionary *result);
typedef void (^TuyaHomeBridgeFailure)(int code, NSString *message);

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

@end

NS_ASSUME_NONNULL_END
