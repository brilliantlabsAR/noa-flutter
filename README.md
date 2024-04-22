# Noa for iOS and Android – A Flutter app for Frame

Welcome to the Noa app repository! Built using Flutter, this repository also serves as a great example of how to build your own Frame apps.

<p style="text-align: center;"><a href="https://apps.apple.com/az/app/argpt/id6450499355"><img src="https://upload.wikimedia.org/wikipedia/commons/3/3c/Download_on_the_App_Store_Badge.svg" alt="Apple App Store badge" width="125"/></a>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://play.google.com/store/apps/details?id=xyz.brilliant.argpt"><img src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg" alt="Google Play Store badge" width="125"/></a></p>

![Noa screenshots](/docs/screenshots.png)

## Getting started

1. Ensure you have XCode and/or Android studio correctly set up for app development

1. Install [Flutter](https://docs.flutter.dev/get-started/install) for VSCode

1. Clone this repository

    ```sh
    git clone https://github.com/brilliantlabsAR/noa-flutter.git
    cd noa-flutter
    ```

1. Get the required packages

    ```sh
    flutter pub get
    ```

1. Connect your phone and run the app in release mode

    ```sh
    flutter run --release
    ```

## Regenerating the platform files

Sometimes it may be necessary to regenerate the platform files. To do this, delete the `ios` and `android` folders, and run the following commands. Adjust for your own organization identifier accordingly:

1. Delete the `ios` and `android` folders

    ```sh
    rm -rf android ios
    ```

1. Regenerate them

    ```sh
    flutter create --platforms ios --org xyz.brilliant --project-name noa .
    flutter create --platforms android --org xyz.brilliant --project-name noa .
    ```

1. Regenerate the app icons

    ```sh
    flutter pub run flutter_launcher_icons
    ```
    
1. Insert the following into `ios/Runner/Info.plist` to enable Bluetooth for iOS

    ```plist
    <dict>
        <key>NSBluetoothAlwaysUsageDescription</key>
        <string>This app always needs Bluetooth to function</string>
        <key>NSBluetoothPeripheralUsageDescription</key>
        <string>This app needs Bluetooth Peripheral to function</string>
        <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
        <string>This app always needs location and when in use to function</string>
        <key>NSLocationAlwaysUsageDescription</key>
        <string>This app always needs location to function</string>
        <key>NSLocationWhenInUseUsageDescription</key>
        <string>This app needs location when in use to function</string>
        <key>UIBackgroundModes</key>
        <array>
            <string>bluetooth-central</string>
        </array>
        ...
    </dict>
    ```

1. Insert the following into `ios/Runner/Info.plist to enable Google sign in for iOS

    ```plist
    <dict>
        <key>CFBundleURLTypes</key>
        <array>
            <dict>
                <key>CFBundleTypeRole</key>
                <string>Editor</string>
                <key>CFBundleURLSchemes</key>
                <array>
                    <string>com.googleusercontent.apps.178409912024-a779l8d62k0r94f8qg63bcs77j986htk</string>
                </array>
            </dict>
        </array>
        ...
    </dict>
    ```

    1. Finally, you may want to find and replace all occurrences of the string `xyz.brilliant` to your own reverse-domain bundle identifier