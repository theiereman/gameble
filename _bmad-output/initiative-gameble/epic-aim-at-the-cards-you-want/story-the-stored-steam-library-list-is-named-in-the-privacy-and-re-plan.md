---
title: 'The stored Steam library list is named in the privacy and retention pages and in the data export'
type: 'feature'
ticket: '8'
created: '2026-11-01'
status: 'built'
baseline_revision: '877f7fc9705a15955f60e69a18009cc7af1157f4'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** Gameble now stores, for a Steam player with the sync on, the catalog games of their Steam library (the `steam_library` custom set with `synced_at` and `library_private_since`), but the legal page's privacy section (what is stored, which services, how long, deletion, rights) never names it, and the data export only carries it as an unnamed `customSets` entry of kind `steam_library`, without its sync dates or the sync setting. Valve's terms require telling players what Steam data is kept.

**Approach:** Copy only: the privacy section of the legal page names the library list in the stored list, the Steam service line, the retention list, the deletion paragraph, the access and objection lines, and the settings line, in both locales, with "Last updated" moved to 1 November 2026. The export gains its own `steamLibrary` section (the set's token, dates and games) and `profile.steamLibrarySync`, and `customSets` lists `custom` sets only.

## Boundaries & Constraints

**Always:**
- Legal copy: keep every existing sentence; only add the items and words below, in `config/locales/en.yml` and `fr.yml` under `pages.legal` (French with a literal U+202F before `: ; ? !` and inside « »). New `<li>`s carry a class so tests can find them.
  - `privacy.stored.steam_library` (new `<li class="legal__stored-steam-library">`, right after `stored.steam`). EN: `if you sign in with Steam and leave "Sync my Steam games" on in the settings: the list of the catalog games your Steam library holds, read from Steam once a day for your "My Steam library" set, with the date of its last sync and, when Steam stops sharing your library, since when;` FR: `si vous vous connectez avec Steam et laissez « Synchroniser mes jeux Steam » activé dans les paramètres : la liste des jeux du catalogue que contient votre bibliothèque Steam, lue chez Steam une fois par jour pour votre set « Ma ludothèque Steam », avec la date de sa dernière synchronisation et, quand Steam ne partage plus votre bibliothèque, depuis quand ;`
  - `privacy.stored.settings`: EN `your settings (profile visibility, reduced motion, Steam games sync);` FR `vos réglages (visibilité du profil, animations réduites, synchronisation des jeux Steam) ;`
  - `privacy.services.steam`: EN `Steam (Valve) handles sign-in and provides your profile name and, once a day while the sync is on, the games of your Steam library;` FR `Steam (Valve) gère la connexion et fournit votre nom de profil et, une fois par jour tant que la synchronisation est activée, les jeux de votre bibliothèque Steam ;`
  - `privacy.retention.steam_library` (new `<li class="legal__retention-steam-library">`, right after `retention.account`; the list goes from 9 to 10 items). EN: `the list of your Steam library's games: as long as the account exists and the sync is on; it is erased at once when you turn "Sync my Steam games" off in the settings or delete your account;` FR: `la liste des jeux de votre bibliothèque Steam : tant que le compte existe et que la synchronisation est activée ; elle est effacée aussitôt que vous désactivez « Synchroniser mes jeux Steam » dans les paramètres ou supprimez votre compte ;`
  - `privacy.deletion`: insert after "your custom sets," / "vos sets perso," the words `your Steam library list,` / `la liste de votre bibliothèque Steam,`.
  - `privacy.rights.access`: EN `... your sign-in methods and your Steam library list included;` FR `... vos modes de connexion et la liste de votre bibliothèque Steam compris ;`
  - `privacy.rights.objection_html`: EN `objection: make your profile private in the settings, turn "Sync my Steam games" off so Gameble stops reading your Steam library, or write to %{contact};` FR `opposition : rendez votre profil privé dans les paramètres, désactivez « Synchroniser mes jeux Steam » pour que Gameble ne lise plus votre bibliothèque Steam, ou écrivez à %{contact} ;`
  - `pages.legal.updated`: EN `Last updated: 1 November 2026`, FR `Dernière mise à jour : 1er novembre 2026`.
- Export (`PlayerExport#to_h`), read through the domains' export queries only:
  - `profile.steamLibrarySync`: the player's stored `steam_library_sync` boolean, after `reducedMotion` (through `Accounts::ExportOf::Profile`).
  - `customSets`: `custom` sets only, same entry shape as today (`token`, `name`, `kind`, `createdAt`, `games`).
  - `steamLibrary`, a new key right after `customSets`: `nil` when the player has no library set, else `{ token:, createdAt:, syncedAt:, notSharedSince:, games: [ { slug:, title: } ] }` (times ISO 8601 UTC or nil, games in insertion order, same slug/title lookup as custom sets).
  - No database id anywhere (`assert_no_database_id` keeps passing).
- Every string in both locales; no planning ids in code or tests.

**Never:** a change to the settings delete dialog, the settings row, the sync or its erase (entries 7 and 15 are built); a new page or section; a Steam call; a migration; rewording an existing sentence beyond the insertions above.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Legal page, French / English | visitor or player | stored, retention, deletion, access, objection and services lines name the Steam library list; 10 retention items; updated 1 November 2026 | No error expected |
| Export, synced library | library set with 2 games, `synced_at` set | `steamLibrary` holds token, createdAt, syncedAt, notSharedSince nil, both games by slug and title; not in `customSets` | No error expected |
| Export, private library | `library_private_since` set | `notSharedSince` set, games kept | No error expected |
| Export, no library set | Clerk player or sync off | `steamLibrary` nil; `profile.steamLibrarySync` the stored value | No error expected |
| Export, custom and library sets | both kinds | `customSets` lists the custom one only | No error expected |
| Account deleted through the controller | Steam player with a library set and games | no `game_custom_sets` and no `game_custom_set_games` row of that set remains | No error expected |

</intent-contract>

## Code Map

- `app/views/pages/legal.html.erb` -- privacy section: add the two new `<li>`s (stored after `.privacy.stored.steam`, retention after `.privacy.retention.account`); everything else is locale copy.
- `config/locales/en.yml` (`pages.legal`, `updated` at ~2121, `privacy:` at ~1941) and `config/locales/fr.yml` (`updated` at 253, `privacy:` at 277; `stored.steam` 282, `settings` 286, `services.steam` 302, `access` 322, `objection_html` 325). en.yml is wrapped by i18n-tasks normalize style (folded lines); fr.yml uses one quoted line per key. Keys within a block are alphabetical in en.yml.
- `app/models/player_export.rb` (139 lines) -- `to_h`, `profile`, `custom_sets`, `custom_set_games`: add `steamLibrarySync`, filter `customSets` to custom, add `steam_library` building the new section; reuse `custom_set_games` faces for both (pass the library's card ids too).
- `app/domains/accounts/app/queries/accounts/export_of.rb` -- `Profile` gains `steam_library_sync`.
- `app/domains/game/app/queries/game/export_of.rb` (144 lines) -- `custom_sets(player)` plucks every kind; add `synced_at`, `library_private_since` to `CustomSetRow` (or a separate `LibraryRow` and a `steam_library` field on `Result`); `Game::CustomSet::CUSTOM` / `STEAM_LIBRARY`, `.custom` / `.steam_library` scopes.
- `app/domains/game/app/operations/game/release_player.rb` -- already deletes every custom set (games cascade); read only.
- Tests to extend: `test/controllers/pages_controller_test.rb` (~880-940: retention count 9 → 10 in both locales, `.legal__updated` assertion at 871 and any other "30 octobre 2026" / "30 October 2026" one, the deletion and stored-vs-deletion tests); `test/models/player_export_test.rb` (`SECTIONS` gains `steamLibrary` after `customSets`; the empty-player test; the custom sets test at ~140 asserts the library in `customSets` and must move to the new section; profile hash at ~87 gains `steamLibrarySync: true`); `test/domains/accounts/export_of_test.rb`; `test/controllers/data_exports_controller_test.rb` (`SteamSignIn`, `json_headers`); `test/controllers/accounts_controller_test.rb` (deleting via `delete account_path(locale: :fr), params: { confirmation: "SUPPRIMER" }`); `test/support/custom_sets.rb` (`create_library_set(player, card_ids:, synced_at:, library_private_since:)`, `fixture_card_ids`).

## Tasks & Acceptance

**Execution:**
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- the legal copy above.
- [x] `app/views/pages/legal.html.erb` -- the two new list items with their classes.
- [x] `app/domains/accounts/app/queries/accounts/export_of.rb` -- `steam_library_sync` on `Profile`.
- [x] `app/domains/game/app/queries/game/export_of.rb` -- the library set's sync dates, custom and library sets told apart.
- [x] `app/models/player_export.rb` -- `profile.steamLibrarySync`, `customSets` custom only, `steamLibrary` section.
- [x] Tests: `test/controllers/pages_controller_test.rb` (new test: in both locales the stored item, the retention item, the deletion paragraph, the access and objection lines and the Steam service line name the library list, exact text for the two new items; counts and dates updated); `test/models/player_export_test.rb` (synced, private and absent library; custom sets exclude it; profile flag; no database id); `test/domains/accounts/export_of_test.rb` (flag read); `test/controllers/data_exports_controller_test.rb` (a Steam player's POST export holds `steamLibrary` with their games by slug); `test/controllers/accounts_controller_test.rb` (deleting the account leaves neither the library set nor its games).

**Acceptance Criteria:**
- Given a visitor, when they open the legal page in French or in English, then the privacy section names the stored Steam library list in what is kept, how long, what deletion erases and how to export or object.
- Given a Steam player whose library set holds two games, when they export their data, then the file's `steamLibrary` lists those games and its sync date, and `customSets` does not list it.
- Given that player, when they delete their account from the settings, then no library set and none of its games remain in the database.

## Implementation Notes

- `Game::ExportOf` reads `custom_sets` through the `custom` enum scope and adds a separate `LibraryRow` (`steam_library` on `Result`, nil without a library set); both share `card_ids_by_set`. `PlayerExport` resolves the slug/title faces once for custom and library card ids (`set_game_faces`), used by `customSets` and `steamLibrary`.
- en.yml: the new keys sit alphabetically (`retention.steam_library` after `reports`, `stored.steam_library` after `steam`); the view order follows the plan. The deletion insertion is anchored on the privacy paragraph only; the settings delete dialog's note, which uses the same wording, is left as it is.
- Verified: the plan's targeted tests (107 runs), the settings and hub `/legal/` system tests, `PARALLEL_WORKERS=3 bin/rails test` (4038 runs, 0 failures), packwerk, zeitwerk, rubocop, planning references, file sizes, i18n-tasks missing/unused, all clean.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `test/models/player_export_test.rb`, "a player with the sync off has no library section and the setting says so", never created a library set, so its `assert_nil hash[:steamLibrary]` passed only because the player had no set, and the name claimed more than it proved — real: the code keys `steamLibrary` on the set's existence, not the flag, and turning the sync off erases the set anyway. Fixed by the implementer: renamed "the profile carries the Steam games sync turned off", the redundant nil assertion dropped; the profile flag assertion stays.

## Design Notes

The export names the list by giving it its own key instead of a `customSets` entry with a null name, so a reader of the file sees it without knowing the internal kind; the setting goes in `profile` beside the other settings. The retention line ties the list to both the account and the setting, since turning the sync off erases it at once.

## Verification

**Commands:**
- `bin/rails test test/controllers/pages_controller_test.rb test/models/player_export_test.rb test/domains/accounts/export_of_test.rb test/controllers/data_exports_controller_test.rb test/controllers/accounts_controller_test.rb test/config/french_typography_test.rb` -- expected: pass
- `bin/rails test test/system/settings_test.rb -n /legal/` and `bin/rails test test/system/hub_test.rb -n /legal/` -- expected: pass
- `PARALLEL_WORKERS=3 bin/rails test` -- expected: pass
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: clean

## Auto Run Result

Status: built.

**Change.**
- **Legal page, privacy section, both locales:** the stored Steam library list is named:
  - in what Gameble keeps, as a new item after the Steam id line;
  - in the settings line ("Steam games sync");
  - in the Steam service line;
  - in a new retention item: as long as the account exists and the sync is on, erased at once when the sync is turned off or the account deleted;
  - in the deletion paragraph;
  - in the access line (the export includes it);
  - in the objection line (turn "Sync my Steam games" off).

  "Last updated" moves to 1 November 2026. French takes U+202F where the rules apply. No existing sentence was reworded.
- **Data export:** a `steamLibrary` section (token, createdAt, syncedAt, notSharedSince, games by slug and title, or null without a library set). `profile.steamLibrarySync` carries the setting. `customSets` now lists custom sets only.
- **Account deletion:** it already erased the set and its games (cascade). A controller test now covers it.

**Files.**
- `config/locales/en.yml`, `config/locales/fr.yml`: the legal copy.
- `app/views/pages/legal.html.erb`: the two new list items (`legal__stored-steam-library`, `legal__retention-steam-library`).
- `app/domains/accounts/app/queries/accounts/export_of.rb`: `steam_library_sync` on the profile.
- `app/domains/game/app/queries/game/export_of.rb`: custom sets apart from the library row with its sync dates.
- `app/models/player_export.rb`: `steamLibrary`, `steamLibrarySync`, custom sets only.
- Tests: `test/controllers/pages_controller_test.rb`, `test/models/player_export_test.rb`, `test/domains/accounts/export_of_test.rb`, `test/controllers/data_exports_controller_test.rb`, `test/controllers/accounts_controller_test.rb`.

**Review.** One quick pass, 1 finding:
- Patched (1, low): a test name that claimed more than it checked.
- Deferred: none. Rejected: none.

Follow-up review recommended: false. This pass patched high 0, medium 0, low 1.

**Verification** (after the patch):
- Targeted tests: 107 runs, 0 failures.
- `test/system/settings_test.rb -n /legal/` (1) and `test/system/hub_test.rb -n /legal/` (3) pass; `test/system/share_card_test.rb -n "/legal page/"` (1) passed before the patch.
- `PARALLEL_WORKERS=3 bin/rails test`: 4038 runs, 0 failures.
- packwerk, zeitwerk:check, rubocop, planning references, file sizes, i18n-tasks missing and unused: all clean.
- No frontend file was touched. No migration.
- Matrix audit: every row has a passing test:
  - the legal page row: the new pages test, both locales;
  - the synced, private and custom-plus-library rows: `player_export_test` and `data_exports_controller_test`;
  - the no-library row: the empty-player export test and the profile flag test;
  - the deletion row: `accounts_controller_test`.

**Copy the UX did not specify.** All of the legal copy above, in both languages:
- the stored item;
- the settings, service, access and objection insertions;
- the retention item;
- the deletion words;
- the date.

**Residual risks.**
- The settings delete dialog's note, which mirrors the deletion paragraph, does not name the library list. The plan left it untouched.
- Export file consumers see the library move from `customSets` (kind `steam_library`) to `steamLibrary`. No code reads the file.
- The legal basis lines (purposes) are unchanged. The library list falls under running the game; the author may want to confirm the basis.
- The legal copy is the author's to approve. It was never checked by eye in a browser.
