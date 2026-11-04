---
tracker_id: ""
key: ""
type: epic
title: "Hotwire Native apps"
parent: initiative-gameble
covers: []
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# Hotwire Native apps

## Description

Players open Gameble from an iOS and an Android app that wrap the same Rails pages in Hotwire Native shells: a native tab bar, push notifications, a sign-in that works where Google refuses a web view, haptics and the share sheet. A first implementation exists on the branch `hotwire-native-v1` of the repository thoKling/gameble; this epic brings it onto `develop`, adapts it to the phone-first web, and sets up the builds and the store submissions.

## Outcome

Phone players who prefer an app find Gameble in the App Store and on Google Play and get a notification when a friend proposes a trade; the signal is installs and the share of trades answered from a notification.

## Requirements

- E1: The Rails app recognises the iOS and Android shells and serves them pages without the web tab bar and without a doubled header.
- E2: A player signs in from the app through the system browser, with Steam, Clerk's methods and Sign in with Apple, and stays signed in; signing out forgets the device.
- E3: A trade offer, a counter-offer, an accepted trade and a friend request reach a registered device as a push notification, in the player's language; a platform with no key sends nothing.
- E4: Each shell shows the four tabs of the phone web and offers haptics on card reveals, the share sheet and the notification opt-in.
- E5: A tag builds signed apps and ships them to TestFlight and the Google Play internal track, one pointing at staging and one at production, with the version taken from the release.
- E6: Each store accepts the submission: account deletion in the app, review notes, a demo path, age and data answers, and a settled answer on the game cover art.

## Done when

1. A player signs in from the iOS app and from the Android app with Steam, with Clerk and with Apple, and is still signed in after closing the app; signing out stops the notifications.
2. A trade proposal on staging produces a notification on a real iPhone and a real Android phone, which opens the trade.
3. At 390 px in a Hotwire Native user agent no screen shows the web tab bar, a doubled header or a bottom action under the native tabs.
4. Pushing a release tag produces a signed iOS build in TestFlight and an Android bundle on the Play internal track, for staging and for production.
5. The submission pack is complete for both stores, with the cover-art question settled in writing.

## Boundaries

The two native shells, their Rails endpoints, their builds and their store submissions. Not the web screens themselves (epic phone-first web), not new native-only features beyond what the first implementation has, and not the legal answer on the cover art, which a person settles.

## References

- research — _bmad-output/initiative-gameble/research-native-mobile-app-store-viability-for-ga/research-native-mobile-app-store-viability-for-ga.md, Go / no-go risk table
- spec — _bmad-output/initiative-gameble/spec-gameble/later-roadmap.md, Native apps
- constraint — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, Non-goals: Native App Store and Play Store apps
- source — https://github.com/thoKling/gameble/tree/hotwire-native-v1, mobile/README.md and the commits from c72e4dc to f5fb257
- epic — _bmad-output/initiative-gameble/epic-phone-first-web/epic-phone-first-web.md

## Notes

- Decision: the author wants the native apps now, in release 1.2.x (2026-11-04); the spec's non-goal no longer holds for this work.
- Decision: Sign in with Apple is part of this epic, since the store requires it once third-party sign-in is offered (author, 2026-11-04).
- Decision: the game cover art is not a separate entry; its right is an unknown inside the store submission entry (author, 2026-11-04).
- Decision: the work of thoKling is brought in with its commits and authorship kept, not copied (2026-11-04).
- Source conflict: spec-gameble.md, Non-goals — native App Store and Play Store apps are out of scope vs the author's request to build them now. Offer the correction to bmad-spec.
- Unknown: whether Valve or the publishers answer a permission request for the cover art; the submission entry waits on it.
- Unknown: how Clerk's Apple provider behaves in the system browser sheet of the shell; the Sign in with Apple entry waits on it.
- Waits on epic phone-first web because: the shells show its four tabs and the web layout must give up its own tab bar and bottom actions in the app.
