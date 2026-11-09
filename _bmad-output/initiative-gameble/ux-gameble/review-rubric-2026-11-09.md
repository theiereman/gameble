# Spine Pair Review — gameble, 2026-11-09 partial update

Scope: the uncommitted changes to `EXPERIENCE.md` (E) and `DESIGN.md` (D), the 2026-11-09 memlog decisions (`.memlog.md` lines 802-834, M), and the rubric's Pass 1 checks where they apply. Line numbers are those of the working files. "Built" means the current code.

## Overall verdict

The new sections are sound and nearly every decision reached them, but the navigation change stopped at the sections it rewrote. IA rows, Chrome rows, the native apps section, Responsive, Key Flows and the visual spine still describe the old menu and tabs, and two public surfaces are shut out by the visitor rules. Three rules in the new Chattomètre section also need settling before a build: where the verdict links, who it may name, and what the panel shows with no data.

## Decision coverage (memlog 2026-11-09)

Carried correctly: M802-803, 805-812, 815-817, 819-820, 823-825, 827-832, 834. M826 is superseded by M827 and rightly absent.

| Decision | Status | Finding |
|---|---|---|
| M804, M818: visitors have a real way to the leaderboard and the market teaser, from the landing | Stated in the IA rows, contradicted by the visitor rules, no landing link defined | H4 |
| M806: reachable without digging | Holds for signed-in players; not for visitors | H4 |
| M813-814: player menu; Comment ça marche into Paramètres | Stated in E:402, contradicted elsewhere; Paramètres has no such entry | H2, M1, M2 |
| M819: panel always on the hub | Missing from the two-column layout | H6 |
| M822: see-more style | Stated, but its reference has no referent in the spine | M8 |

Stated as author decisions in the spines with no memlog entry: see L2.

## High

**H1. Native apps keep the old tabs and override the new ones** (E:709, E:719, E:732, against E:74).
E:709 still lists PONT · CAPSULE · SETS · AMIS · ÉCHANGES and says this section wins over Phone navigation for the apps, so the apps would keep AMIS (against M812) and have no MARCHÉ (against M810). E:719 gives the avatar menu as Mon profil, Comment ça marche, Réglages, support and source, against E:402. E:732 omits Amis, which now belongs to no tab.
*Fix:* E:709 reads PONT · CAPSULE · SETS · ÉCHANGES · MARCHÉ. E:719 reads Moi, Amis, Paramètres, Soutenir. E:732 reads "Moi, Amis, Paramètres". If the apps are meant to differ, say so and record the decision.

**H2. Information Architecture rows give menu numbers and tabs that no longer exist, and they collide with the new ones** (E:38, E:52, E:53, E:54, E:55, E:64, E:67, E:532).

| Line | Says | Should say |
|---|---|---|
| E:38 Toutes les cartes | Menu 03 (collides with E:44 Échanges) | The new menu has no entry for it, as built. Keep "TOUTES LES CARTES ▸" in the collection and the SETS switch; drop "Menu 03" |
| E:52 Succès | Menu 05 (collides with E:49); the Moi tab | Menu 07; "Tout voir" on Moi |
| E:53 Comment ça marche | Menu 06 (collides with E:50); the Moi tab; "no menu or Moi tab" | Menu 08 EXTRAS on desktop; Paramètres at every width; the landing footer for a visitor |
| E:54 Moi | The MOI tab; "Mon profil" on desktop; Comment ça marche and Paramètres at its foot | "Moi" in the player menu at every width; remove the foot, which E:403 retires |
| E:55 Profil et paramètres | "Paramètres" at the foot of Moi on the phone | "Paramètres" in the player menu; add Comment ça marche and the source code to its purpose column (see M1) |
| E:64 Soutenir | Menu 07 (collides with E:72's 07 SUCCÈS) | The player menu, Menu 08 EXTRAS, the landing |
| E:67 Plus | "the Moi tab", "the four tabs" | Its address leads to Moi (built: `config/routes.rb:199`); "within two taps of the tabs" |
| E:532 Friend presence | "Amis, menu 05" | "Amis, player menu" |

**H3. The back button still returns to the retired Social, and the phone's back labels are no longer defined** (E:238, E:74).
E:238 says Échanges, Amis and Fil d'activité read "◀ SOCIAL" and return to Social at every width. E:43 retires Social, whose address now leads to Amis, so the back from Échanges or the feed would land on Amis. E:74 deleted the list of contextual backs and points to Native apps, which covers only the app's top bar, so a phone browser has no parent for any screen. Built: `fortune_registers/show.html.erb:6` backs to `more_path` with the label "Plus", which is stale against E:74's PONT tab.
*Fix:* restore the list in E:74: "◀ GRILLE", "◀ CAPSULE", "◀ LISTE", "◀ PONT" (Fil d'activité, Le Chattomètre). Échanges and Marché are tab roots with no back. Amis, Moi, Succès, Comment ça marche and Profil et paramètres name the previous screen, as "Belongs to no tab" does in E:732. Remove the "◀ SOCIAL" sentence from E:238.

**H4. The visitor rules shut out the two new public surfaces, and no route to them is defined** (E:78, E:485, E:866, against E:50, E:51, M804, M815, M818).
E:78 and E:485 list what a visitor reaches and send "anything else" to the landing; neither Le Chattomètre nor Marché is listed. E:866 leaves the landing's link open as a non-blocker, yet it is the only route M818 allows, and the Landing section and copy deck hold no link to either.
*Fix:* add both screens to E:78 and E:485. Move the landing links out of Open questions and name their place: for example, a See-more link "Voir le Chattomètre" in 04 · En direct and a marché line in 06 · Feuille de route, with copy in E:179-195. The author should confirm the places.

**H5. With the feed panel gone, the spine leaves the phone with no route to Fil d'activité** (E:49, E:76, E:253, E:696).
E:49 offers Menu 05, which the phone lacks (E:696), and the LIVE ticker. E:253 says the ticker "holds nothing focusable" and is hidden from assistive technology. The removed panel's "OUVRIR LE FIL" was the only visible phone route. Built: `shell/_ticker.html.erb:3` has an overlay link, `ticker__open`, with a hidden label, which the spine contradicts and a player cannot see.
*Fix:* make the ticker a declared route: E:253 says the whole band is one link to the feed, with accessible name "Ouvrir le fil d'activité", and the rest stays hidden from assistive technology. Then state a visible cue in D:1068, or add a phone-only See-more link "Voir le fil" under the ticker. The second option is the author's call, since M819 removed the panel for duplicating the ticker.

**H6. The Chattomètre panel has no place at some widths** (E:76, D:665, E:696, against E:301, M819).
E:76's two-column sentence stacks the menu, mission, daily capsule and "SETS EN COURS" with no panel, and D:665's Hub row gives no width a place for it. E:696 omits it on the phone while E:76 includes it.
*Fix:* add "then the Chattomètre panel" to E:76's two-column stack, to all three width columns of D:665 (the right column at 1180px and over, after the daily capsule), and to E:696.

**H7. The week's verdict links to a screen that cannot show it** (E:303-305, E:50).
From Monday to Wednesday the panel shows last week, but "Voir tout le classement" and the Monday feed entry open the full screen, which holds only the current week and all time (E:50; built: `FortuneStanding::PERIODS = %i[week all_time]`). On Monday the verdict's link lands on a nearly empty table.
*Fix:* during the verdict window, the full screen opens on last week's table, with a third period "Semaine dernière" that the Monday feed entry links to for good. If the author prefers no third period, the entry and the link must say they open the current week.

**H8. The verdict can name a friends-only player to everyone** (E:303, E:304, against E:306, E:535).
E:306 makes a friends-only player an anonymous row for anyone but a friend, but E:304 only protects a private profile, and the feed is open without an account. E:303's "the winner and their title", and the top 3 in E:301, have no rule either.
*Fix:* extend E:306 to every Chattomètre surface: "The panel's top 3, the verdict's winner and the weekly feed entry follow Rows." The feed entry shows the anonymous form unless the winner's profile is public. Define the anonymous form in the copy deck (built: `fortune_registers.show.hidden_player`).

**H9. The visual spine still draws the old tab bar and a retired screen** (D:919, D:921-923).
D:919 lists PONT, CAPSULE, COLLECTION, ÉCHANGES, PLUS. D:921-923 specify PLUS rows for a screen retired on 2026-11-02, including AMIS and FIL D'ACTIVITÉ entries.
*Fix:* D:919 reads PONT, CAPSULE, SETS, ÉCHANGES, MARCHÉ. Remove the PLUS rows. Name the MARCHÉ icon: `app/frontend/images/pixel/` has no market tab icon, and it must come through `script/pixel_art/export.mjs`.

## Medium

**M1. Comment ça marche has no defined entry in Paramètres** (E:402, E:405-416, D:1095 onward, E:72).
E:402 moves it and the source code to Paramètres, but the Profil et paramètres section and its visual spec have no such row. E:72 also keeps both, with Soutenir, in 08 EXTRAS, so desktop has two homes and nothing says that is intended. Built, `shell/_phone_menu.html.erb:10` still lists it in the menu.
*Fix:* add a row to Profil et paramètres ("Aide": Comment ça marche, Code source, with their place under Mentions légales) and to D's Profile and settings. State in E:72 that EXTRAS keeps these links on desktop by design, or remove them.

**M2. Two definitions of the player menu, and the phone's is not an avatar** (E:233, E:402, D:886, D:899).
E:233 still lists Paramètres, Mon profil, Back-office, Se déconnecter. E:402 says "under the avatar at every width", but the spine gives the phone browser no avatar. Built, it is a hamburger shown only on top-level screens (`shell/_phone_menu.html.erb`, `.top-bar--top-level .phone-menu`), and `shell_top_level_screen?` has no MARCHÉ.
*Fix:* E:233 points to E:402. D:886 states the phone top bar's avatar and on which screens it shows; E:402 says "on the top-level screens on the phone, MARCHÉ included". Settle the sign-out placeholder at the same time.

**M3. The avatar's single badge is undefined and the older badge rules are stale** (E:74, E:402, E:236, E:401).
E:74 says one badge "covers what it holds". The player menu holds invitations (violet, E:236) and achievement rewards (E:401, still "the MOI tab carries the same badge"). Nothing says whether it sums them, what colour it takes, or how the Moi line shows its detail. E:236 still names "04 SOCIAL and the phone's SOCIAL tab", and E:72 dropped the menu's badges and metas with no replacement.
*Fix:* define the badge in E:236: for example, the sum of invitations and unclaimed rewards, violet, hidden at zero, with its counts in the accessible name. Move E:401's badge to the avatar and the player menu's Moi line. Restate menu badges and metas for 01, 02, 03 and 07, with Échanges' orange badge on menu 03.

**M4. Responsive still describes the old phone** (E:696, E:699).
E:696 says the menu lives in "the tab bar, Social and the Moi tab". E:699 calls Moi the MOI tab's root with Comment ça marche and Paramètres at its foot, which E:403 retires.
*Fix:* E:696 reads "The menu lives in the tab bar and the player menu (no numbers)". E:699 reads "Moi on the phone: opened from the player menu; …" without the foot.

**M5. The bell's mission line still opens the retired Social** (E:234, E:318).
E:234 says both weekly-mission lines "open Social's weekly mission". Built: `bell_helper.rb:59` goes to the hub's `community-goal` anchor.
*Fix:* E:234 reads "open the hub's weekly mission panel".

**M6. Menu keys and the menu's visual row are out of date; EXTRAS has no behaviour** (E:235, E:563, D:913, E:72).
Keys "1 to 7" should be 1 to 8. D:913 keeps "01 to 09; 03 TOUTES LES CARTES" and the "2 en ligne" meta. EXTRAS is named once, with no rule.
*Fix:* update the three lines, and add the built behaviour to E:235: EXTRAS swaps the list for its four entries, keys 1 to 4 within it, a back row closed with Escape.

**M7. Key Flows use the old navigation** (E:778, E:780, E:791).
Flow 2 has Léa on "the SOCIAL tab" and "from Social", and Hugo on "04 SOCIAL". Flow 3 opens Personnalisation from the player menu, retired on 2026-11-03.
*Fix:* E:778 reads "the ÉCHANGES tab and opens the trade from the list". E:780 reads "03 ÉCHANGES". E:791 reads "From her player menu she opens Moi and taps the Dos de carte opener", and the flow's later steps follow that sheet.

**M8. The see-more rule points at a panel the spine says does not exist** (E:208, E:76, D:747).
E:208 cites "the goals panel"; E:76 says the bridge has "no OBJECTIFS panel", while M822 cites "Objectifs en cours" on the hub and the built `pages/_goals_in_progress.html.erb` shows it. D:747 does not carry the placement outside the frame.
*Fix:* either correct E:76 to describe the built section, or have E:208 cite "SETS EN COURS"'s "TOUT VOIR ▸". Add to D:747: "See-more: outside the panel's frame, at its lower right."

**M9. The gauge's colours break two stated colour rules** (D:1207, against D:589, D:579).
D:589 says gold "is never a general accent", yet the panel's title and the gauge's peaks use it. D:579 reserves `{colors.dim}` for decoration, yet the −500, 0 and +500 labels are readable information in it.
*Fix:* add an exception to D:589 for the Chattomètre's heat and title, or use another token for the title. Set the labels in `{colors.muted}`, updating the mock.

**M10. New components lack visual specs** (rubric check 3; E:301, E:304, E:308, E:402, D:1205).
D has only the gauge: no hub panel layout (tabs, index, comic title, top-3 row), no Player menu, no Marché screen, no verdict state. The weekly feed entry fits neither D:1067's card-led row nor a feed filter (E:356), and nothing says whether it joins the ticker.
*Fix:* add Hub panel, Player menu and Marché blocks to D's Components. Give the weekly entry a row without a card, a filter placement (TOUT only is the simplest) and a ticker rule.

**M11. State coverage of the panel is incomplete** (rubric check 4; E:301-302, E:479-553).
E:302 covers only the marker. Undefined: what stands in place of the index and comic title with no standing; a period with no ranked player, or a Monday with no winner; a top 3 with fewer than three; whether a top-3 row opens the player card as the full screen's does (built); whether the panel updates live or on load. State Patterns has no Chattomètre row.
*Fix:* add a row to State Patterns: no standing shows a line in place of the index ("Ouvrez une capsule pour entrer au classement"); an empty period shows the empty curve and one line; shorter top 3 shows only its rows; top-3 rows follow the Rows rule; the panel updates on load only.

**M12. No copy deck rows, and the panel's key terms are undefined** (E:50, E:301, E:303, E:102-198).
The copy deck has nothing for Le Chattomètre, Marché or the player menu, though every string needs both locales; the built English name is "The Flukeometer". "Index", "comic title" and PRIVILÉGIÉ (in the mock) are defined nowhere, and E:50's "Fortune section" appears nowhere else in either spine. The panel's "Semaine / Total" differs from the built screen's "Cette semaine / Depuis toujours".
*Fix:* add copy deck rows for both screens and the menu, in French and English. Add one line defining the index (−500 to +500), its comic titles and PRIVILÉGIÉ. Describe the profile's Fortune section or name its source. Use one pair of period labels.

## Low

**L1. The Social remnants are acknowledged but wider than stated** (E:867, E:312-322, E:161).
E:867 mentions the section only; the copy deck row at E:161 should go with it. *Fix:* extend E:867 to E:161, or prune both.

**L2. Decisions attributed to the author with no memlog entry** (E:50, E:306, E:402).
"A private profile never appears" and "the source code lives in Paramètres" have no memlog entry; only "Comment ça marche" is in M814. *Fix:* add the entries, or mark the second `[ASSUMPTION]`.

**L3. The roadmap still states the gate that the spine supersedes** (E:310, `spec-gameble/later-roadmap.md:11`).
`later-roadmap.md` still holds the seniority gate and is not in E's `sources`. *Fix:* update the roadmap line and add the file to `sources`.
