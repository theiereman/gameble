# Gameble mobile apps

The iOS and Android apps are Hotwire Native shells around the Rails app. Every
screen is the web page, served by Rails. The shells add a native tab bar, the
navigation, sign-in through the system browser, push notifications, the share
sheet and haptics.

## How the apps talk to Rails

- **App detection.** The apps' user agent contains `Hotwire Native`, so
  `hotwire_native_app?` is true. The layout then marks `<html data-native-app>`,
  leaves out the web tab bar, and hides the web back buttons.
- **Path configuration.** `public/configurations/ios_v1.json` and
  `android_v1.json` say how each URL is shown. Each app also bundles a minimal
  copy for its first launch.
- **Bridge components** (`app/frontend/controllers/bridge/`). A component only
  loads in an app that declares it in its user agent, so the web is unchanged.
  - `sign-in`: the sign-in page asks the app to sign in in the system browser.
  - `push-permission`: the settings row that asks for notifications and
    registers the device token.
  - `share`: the share sheet for the friend invite link.
  - `haptics`: a buzz on each card reveal, stronger for rarer cards.
- **Sign-in hand-off.** Google refuses OAuth inside web views, so the app opens
  `/:locale/native/sign-in/:state` in ASWebAuthenticationSession on iOS, or in
  a Custom Tab on Android. The player signs in there with Steam or Clerk, then
  taps "Back to the app". That redirects to `gameble://sign-in?ticket=…`, a
  ticket signed for two minutes and bound to the app's random state. The app
  posts ticket and state to `/:locale/native/session`, copies the session
  cookie into its web views, and reloads its tabs.
- **Push notifications.** Devices are stored in `accounts_push_devices`.
  `PushNotices` turns trade offers, counter-offers, accepted trades and friend
  requests into notifications through `action_push_native`. Signing out
  forgets the device the session registered.

## Server configuration

Set these environment variables in production. A platform without its keys
sends nothing.

| Variable | What |
| --- | --- |
| `APNS_KEY_ID`, `APNS_TEAM_ID` | The APNs auth key's id and the Apple team id |
| `APNS_ENCRYPTION_KEY` | The contents of the `.p8` APNs auth key |
| `APNS_TOPIC` | The iOS bundle id (default `net.gameble.app`) |
| `APNS_DEVELOPMENT` | `on` to push to apps built from Xcode |
| `FCM_PROJECT_ID` | The Firebase project id |
| `FCM_SERVICE_ACCOUNT` | The Firebase service account JSON |

## iOS

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) and run
   `xcodegen generate` in `mobile/ios`, then open `Gameble.xcodeproj`.
2. Set your team under Signing & Capabilities. Push Notifications is already
   declared in `Gameble.entitlements`.
3. Debug builds load `http://localhost:3000`, release builds load
   `https://gameble.net` (`GAMEBLE_ROOT_URL` in `project.yml`).

## Android

1. Open `mobile/android` in Android Studio, or build with `./gradlew assembleDebug`.
2. Create a Firebase project with the Android app `net.gameble.app`, and put
   its `google-services.json` in `mobile/android/app/`.
3. Debug builds load `http://10.0.2.2:3000` (the host from the emulator),
   release builds load `https://gameble.net`.

## Not done yet

- App icons and launch screens. The Android app uses a system icon for now.
- Linking another sign-in method from the settings still runs Clerk inside
  the web view, where Google refuses it.
- A rotated FCM token is only sent again when the player turns notifications
  on again.
- Neither shell has been built in CI yet.
