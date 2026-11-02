# Digest: Steam login in mobile apps, round 1, assistant 1 (accessed 2026-11-02)

Fetch summaries came from a small model: secondary. Budget mostly spent on shallow fetches; (a), (b), (c), (e) only partly answered.

## Claims
1. Apple 4.8 requires an equivalent privacy-focused login (data limited to name and email, email can be hidden, no ad tracking without consent) when the app uses a third-party or social login "to set up or authenticate the user's primary account". Named examples: Facebook, Google, X, LinkedIn, Amazon, WeChat; Steam not named. Exemptions: own account system only; alternative marketplaces; education/enterprise/business apps requiring an existing account; government or industry ID systems; a client for a specific third-party service where users sign in directly to that third-party account to access its content.
   - Source: https://developer.apple.com/app-store/review/guidelines/ , Apple, no date shown. Confidence high for text. Class: primary doc. Only the first 100k of 114k chars read; 4.8 was inside.
   - Inference (untested): Steam-only login for gameble's own accounts most likely counts as a third-party login for a primary account. The client-for-a-service exemption fits a pure Steam client, probably not gameble (own cards and game state).
2. Valve's auth doc: Steam is an OpenID 2.0 provider; OP endpoint https://steamcommunity.com/openid/ ; claimed id http://steamcommunity.com/openid/id/<steamid>; the browser is redirected back to the third-party site with OpenID data on the return URL. No mention of mobile apps, return-URL rules or terms. Sign-in button images "may be used by 3rd party sites".
   - Source: https://partner.steamgames.com/doc/features/auth , Valve, no date. Confidence medium-high. Class: primary doc.
3. Clerk: Steam not in the built-in social provider list (search summary: list runs "AgentID" to "Xero"). Custom OAuth provider guide exists; Steam uses OpenID 2.0, not OIDC, so a custom provider likely needs an adapter (assistant inference, unverified). Clerk has iOS, Android, Expo SDKs. Apple support in them not confirmed. Free tier reportedly 3 social providers, 50,000 MRU (search summary, low).
   - Source: https://clerk.com/docs/guides/configure/auth-strategies/social-connections/overview , Clerk, no date. Confidence low-medium.
4. Anecdote: Fitbit developer thread reports Apple requiring Sign in with Apple for an app using Fitbit web login. Source: https://community.fitbit.com/t5/Web-API-Development/Apple-Rejecting-Apps-That-Use-Fitbit-Login/td-p/4543957 . Snippet only. Confidence low. Class: anecdote.
5. Blogs (ptkd.com, vp0.com): a 4.8 rejection is fixed by a new binary, not a reply; a custom login meeting the three criteria is acceptable. Low confidence, blog. https://ptkd.com/journal/app-store-rejection-4-8-sign-in-with-apple-requirement-fix
6. ASWebAuthenticationSession needs a strong reference and a custom callback URL scheme; one forum report says Universal Links are not triggered by a JS redirect inside it. Search snippets about OIDC, unverified. Low.

## Not found
- Any named app, reviewer or outcome for 4.8 applied to Steam, Epic, Xbox, PSN or Discord logins.
- Which shipped apps use Sign in with Steam and how; issues with Steam's login in embedded WebViews or custom-scheme return URLs (Valve doc silent).
- Whether "Sign in with Apple first, link Steam later" is allowed: not confirmed by any retrieved text.
- Google Play login/account-deletion rules (not searched here).
- Clerk Apple support in native SDKs; any native Steam flow.

## Leads
- Clerk pages: ios social-connections overview; social-connections/apple.
- https://developer.apple.com/forums/thread/689031 ; search "Discord login Apple rejected 4.8", "Epic Games login 4.8".
- Open-source Steam-login apps (e.g. SteamViewer) for the mobile flow.
