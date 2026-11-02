---
title: 'Technical research: native iOS and Android apps for a free Steam trading card game'
type: 'technical'
topic: 'Native app store viability for a free Steam-based trading card game'
decision: 'Pay store fees and build Hotwire Native apps, or not'
source: 'native run'
status: draft
preset: 'deep (one round, budget-limited)'
validation: 'normal'
created: '2026-11-02'
updated: '2026-11-02'
---

# Technical research: native iOS and Android apps for a free Steam trading card game

**Decision this research serves:** whether to pay the store fees and build Hotwire Native iOS and Android apps for a free web trading card game in which every card is a Steam game (Steam OpenID sign-in, random free packs, player-to-player trading, no real money).

Not legal advice. Digests live in `digests/`; most store-policy pages were read through a summarising fetch tool, so exact wording should be re-read before submission.

## Executive summary

- **Gambling and loot-box rules do not reach a free, purchase-free pack app on the text of Apple 3.1.1 / 5.3 and Google's gambling and payments policies** [A1][G1]. Expected Apple age rating 4+ or 9+ (inference). The risk is reviewer perception of the name and pack mechanic, not the rules.
- **Two real blockers:** (1) Apple 4.8 applies: the app offers Steam, Discord and Google sign-in (Google Sign-In is named in the guideline), and email sign-in cannot hide the address, so Sign in with Apple must be added [A2]; (2) publisher-owned cover art has no written license from Valve or anyone, and both Apple 5.2 and Google's IP policy require permission for third-party content and name game cover art as a typical violation [A3][G1].
- **No precedent of enforcement was found** against Steam-data apps over cover art; several Steam-data apps are live on the App Store [P1]. Absence of evidence is not safety.
- **Hotwire Native is a sound technical fit** (Stimulus-based bridge, 37signals-backed, active releases) but 1.3.0 is breaking and real review risk sits in 4.2 and business rules, not the web view [H1].

## 1. Valve and publisher rights

Valve's terms (read in full by an earlier fetch) license Steam Data to end users "for their personal use", forbid implying Valve endorsement, and are silent on cover art, mobile apps, caching and OpenID in apps [1]. The Subscriber Agreement restricts commercial exploitation and aggregation of Steam content without Valve's written consent [2]. Valve's asset rules only govern what may appear on Steam capsules [3]. No Valve statement on third-party reuse of store art was found; no Valve takedown over capsule art was found, only actions against skin-gambling sites, mods and hardware [P1]. Publishers do DMCA third-party art databases (SteamGridDB, 2022, Nintendo titles) [P1]. Confidence: high on the terms' silence, low on enforcement likelihood.

## 2. Apple

- **Gambling and loot boxes.** 3.1.1 odds disclosure applies to randomized items "for purchase"; every 5.3 sub-rule concerns real money, sweepstakes or lotteries; the age-rating "Loot Boxes" descriptor is defined as items "for purchase" [A1]. A reviewer anecdote shows 5.3.4 can be invoked on gambling-looking surface cues; mitigate with review notes stating no real money and no prizes (low-medium) [A1].
- **Login.** 4.8 text (revision 2026-10-16) covers any app using a third-party login for its primary account. The project already offers Steam, Discord, Google and email through Clerk (Steam via OmniAuth), and a player without Steam is allowed; Google Sign-In is named in 4.8, so the guideline applies regardless of how Steam is classified. The client-of-a-service exemption fits poorly. The reported "January 2026 extension" was not verified; the current text already has no "exclusively" qualifier [A2]. Sign in with Apple satisfies 4.8. An Apple-only player is a player without Steam, already allowed; linking Steam later is already a settings feature.
- **IP.** 5.2.1 and 5.2.2 require permission for protected third-party material and for displaying a third-party service's content, with "authorization ... provided upon request"; 4.1(c) bars another developer's brand in icon or name [A3].
- **4.2.** A bare wrapper risks rejection; native tab bar, push and menus are the usual mitigation; some developers still report repeated 4.2 rejections despite native features (forum threads, unread) [A3][H1].
- **Other.** Reviewers need a demo path: a Steam-only login raises the Steam Guard problem; account deletion in-app is mandatory.

## 3. Google Play

Gambling policy targets real-money wagering; odds disclosure is tied to purchase; IARC allows simulated gambling at 12+ [G1]. The IP policy explicitly lists game cover art among typical violations, requires proof of rights on request and has no fair-use exception [G1]. No mandated alternative sign-in was found. Account deletion (in-app plus web link) and Data safety are required. A personal developer account needs a 12-tester, 14-day closed test before production; an organization account needs a D-U-N-S number [G2]. New apps must target API 36 (search summary, medium). Spam policy bans web-view apps made without the site owner's permission; a wrapper of your own site is not caught on its face.

## 4. Hotwire Native

Latest releases: iOS 1.3.1 (2026-08-14), Android 1.3.2 (2026-10-12); both repos active (24 open issues each) [H1]. 1.3.0 broke route-handler and error APIs. Bridge components are Stimulus controllers, matching the project's TypeScript Stimulus stack. A practitioner reports almost never seeing rejections for being a web view after 25+ apps; rejections came from Sign in with Apple, in-app purchase and account deletion (single source with commercial interest). Auth is not covered by the docs; the practitioner pattern is a long-lived cookie shared across web and native with a bridge sign-in event; OAuth in a system browser sheet has only a community gist. Not confirmed: built-in push and haptics components, server-side native detection.

## Go / no-go risk table

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Publisher cover art rejected or taken down (Apple 5.2, Google IP) | Medium | High (rejection or removal) | Written Valve permission; ready proof-of-rights answer; ability to swap covers for generic art |
| Apple 4.8: third-party logins offered without Sign in with Apple | Certain | High (rejection) | Enable Apple in Clerk (to confirm in Clerk docs, including native flow in the Hotwire Native shell) |
| Reviewer cannot log in (Steam Guard) | Medium | Medium | Demo account or approved demo mode; Apple login as easier path |
| 4.2 wrapper rejection | Medium | Medium | Native tabs, push, haptics via bridge components |
| Gambling/loot-box perception ("gameble", packs) | Low-medium | Medium | Review notes; accurate rating answers; consider pack odds screen |
| Hotwire Native upgrade churn (1.3.0 breaking) | Medium | Low | Pin versions |
| Google closed-test requirement | Certain | Low | Plan 12 testers for 14 days |

**Reading:** no policy blocks the app outright; two items need action before paying (Valve/publisher permission for covers, Sign in with Apple). The unresolved cover-art right is the one risk that fee money cannot buy back.

## Open questions

- Does Valve answer a permission request, and would publishers be expected to consent individually? (No source found.)
- Haptics and push as built-in bridge components; APNs and FCM wiring; server-side native detection.
- Android OAuth via Custom Tabs and cookie sharing.
- Odds-disclosure UI of comparable apps; IARC questionnaire handling of free packs.
- Clerk is already integrated (Discord, Google, email; Steam via OmniAuth). Not confirmed by this research: Clerk's Apple provider and how its sign-in page behaves inside the Hotwire Native web view or a system browser sheet.
- Rounds 2 and 3 were not run; a further round would target these.

## Sources

[1] Valve, Steam Web API Terms of Use (last updated July 2010), https://steamcommunity.com/dev/apiterms, accessed 2026-11-02.
[2] Valve, Steam Subscriber Agreement, https://store.steampowered.com/subscriber_agreement/, accessed 2026-11-02 (sections 7-11 unread).
[3] Valve, Graphical Asset Rules, https://partner.steamgames.com/doc/store/assets/rules, accessed 2026-11-02.
[A] Apple, App Review Guidelines (updated 2026-10-16), https://developer.apple.com/app-store/review/guidelines/; Age ratings definitions, https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions; accessed 2026-11-02.
[G] Google Play policy pages: https://support.google.com/googleplay/android-developer/answer/9877032, /9858738, /9888072, /13327111, /14151465, /9899034, /9898783; accessed 2026-11-02.
[H] hotwired/hotwire-native-ios and -android release data, GitHub API; https://native.hotwired.dev/; Masilotti, https://newsletter.masilotti.com/p/what-ive-learned-from-shipping-25 (2026-02-19) and https://masilotti.com/hotwire-native-app-store-tips/ (2023-08-14).
[P] Precedent digests: `digests/precedents-r1-1.md`, `digests/steam-login-r1-1.md`.
