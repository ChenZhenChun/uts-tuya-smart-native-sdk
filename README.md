# Tuya Smart Native SDK

Native vendor dependency repository for `uts-tuya-smart-sdk`.

## iOS

This repository exposes Tuya's app-specific security SDK as a CocoaPods pod named `ThingSmartCryption`.

```ruby
pod 'ThingSmartCryption',
    :git => 'https://github.com/ChenZhenChun/uts-tuya-smart-native-sdk.git',
    :tag => 'v5.0.1'
```

`ThingSmartHomeKit` is still resolved from Tuya's pod specs:

```ruby
pod 'ThingSmartHomeKit', '~> 7.8.0'
```

## Android

The Android folder keeps the app-specific Tuya security AAR:

```text
android/security-algorithm-1.0.0-beta.aar
```

The UTS plugin currently keeps this AAR locally under `utssdk/app-android/libs`.
This repository also includes Gradle publishing metadata for optional JitPack usage.
