# Store submission pack

What each store asks for, and where the answer lives. Items marked **person** need the author's accounts.

## Where we stand (2026-11-05)

Do not merge `feature/hotwire-native` into `develop` until everything below is validated: a merge would put its features in the next production release.

- [x] Android keystore secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`)
- [x] Apple credentials filled in Clerk (Services ID, key, Team ID, Key ID)
- [x] Apple sign-in tried on a server (the branch deployed to staging)
- [x] `APPLE_TEAM_ID` secret (Team ID: developer.apple.com/account, Membership details)
- [x] App Store Connect API key and its three secrets
- [ ] Push: APNs key, Firebase project, `google-services.json`, server variables
- [ ] Google Play account validated, app created, service account JSON in `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
- [ ] Closed test with 12 testers for 14 days
- [ ] Icons and launch screens
- [ ] Release candidate build, real-device check, store listing, cover-art answer

## Accounts and secrets (person)

| Need | Where it goes |
|---|---|
| Apple Developer Program, app `net.gameble.app`, Sign in with Apple and Push capabilities | App Store Connect |
| App Store Connect API key (`.p8`) | secrets `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_BASE64`, `APPLE_TEAM_ID` |
| Apple as a provider in Clerk (Services ID and key) | Clerk dashboard |
| Android upload keystore | secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` |
| Google Play service account with release rights | secret `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` |
| APNs key and FCM service account | env vars listed in the push configuration |

## Review notes (both stores)

- The app is the Gameble web game inside a native shell with four tabs (Capsule, Sets, Social, Me), native sign-in hand-off, haptics, sharing and push notifications for trades and friend invitations.
- Reviewers sign in with an email code or Apple; Steam sign-in needs Steam Guard and cannot be used by a reviewer. Provide a demo account whose email code the author reads out, or a seeded account on the staging server. **person**
- Sign in with Apple is offered next to Discord, Google and the email code (guideline 4.8).
- The game is free, has no purchases and no ads.

## Account deletion

Players delete their account in Settings, under the danger zone, by typing the confirmation word. The same page is reachable on the web at `/<locale>/settings`. Give this path in both consoles' account-deletion field.

## Privacy and data answers

- Data collected: Steam id or provider identifier, display name and avatar, email (hashed for matching), game activity (cards, trades, feed), push token. Sign-in sessions are handled by Clerk as a processor.
- No tracking across apps, no advertising identifier. The legal page at `/<locale>/legal` holds the privacy policy to link.
- Export: players can export their data from Settings.
- Age rating: no violence beyond card-game content, no gambling with real money, user-to-user trading of virtual cards with no cash value. Answer the questionnaires accordingly. **person**

## Game cover art

Cards show Steam store cover images. Apple 5.2 and Google's intellectual-property policy ask for the right to use them. Ask Valve and the publishers for a written answer (or document the Steam Web API terms of use) and attach it to both submissions. Unresolved: whether anyone answers.

## Google Play personal account

A personal developer account needs a closed test with at least 12 testers opted in for 14 days before production access. Start the internal track early, then recruit testers. **person**

## Store listing

Name, short and full description, screenshots (6.9-inch iPhone, 6.5-inch iPhone, Android phone), 1024×1024 icon and 512×512 icon, feature graphic 1024×500, in English and French. Screenshots come from the staging server with seeded data. **person**
