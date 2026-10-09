---
title: 'The legal page says what the app really does'
type: 'feature'
ticket: '22'
created: '2026-10-09'
status: 'built'
baseline_revision: '1cf0684aebee0452c121667358a547eb86645888'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The legal review of 2026-10-09 found the legal page's privacy notice and terms incomplete and, in places, contradicted by the code: no purposes or legal bases, rights limited to access, deletion and complaint, a deletion called "anonymisation" that keeps pseudonymised rows, Sentry said to receive "the player id only", the IP address and moderation data missing from what is stored, the public-by-default profile unstated, no takedown channel, no human-decision or appeal wording, and nothing in the sign-in panel tells a visitor that signing in accepts the terms.

**Approach:** Rewrite the `pages.legal.*` copy in `fr.yml` (source) and `en.yml` (same text, same "vous"/"you" register) with the exact wording in Design Notes, add the matching lines to the legal view, add an acceptance line with links to the terms and privacy anchors under the Steam button of the sign-in panel, and fix two labels (public visibility, report reason). The parts that need an author decision stay as they are.

## Boundaries & Constraints

**Always:**
- Every sentence matches the code as checked during planning (Design Notes, "Facts checked"). French copy is the source; English carries the same content.
- Every new string exists in both locale files; plural keys untouched; `i18n-tasks missing` and `unused` stay clean.
- Rights bullets and terms that name the contact take `%{contact}`: the `mail_to` link when `config.x.legal.contact_email` is set, else the plain words of `pages.legal.contact_fallback` ("l'éditeur" / "the publisher"). The existing `access_html` / `access_publisher` pair stays as it is.
- No `style` attribute; no planning ids in code, tests or comments; links in the panel are plain `link_to` to `legal_path(anchor: ...)` in the current locale.
- Legal copy is a draft for the author's review.

**Never:**
- Do not touch `config/initializers/event_store.rb`, `config/initializers/legal.rb` (no boot-time requirement for `LEGAL_*`), the host lines, the default visibility, the ban flow, or retention periods (no `privacy.retention` key, no "durées indiquées" phrasing).
- Do not name a Sentry region or a hosting country; do not add the Cloudflare/US transfer sentence (the repo does not show Cloudflare actually in front: production has no server, staging is behind Traefik).
- Do not add a legal link to pages other than the sign-in panel.
- Do not change the "Mentions légales" / "Legal notice" link labels in the settings and the public card footer (`settings.show.legal`, `cards.show.legal`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Legal page FR, contact set | `GET /fr/legal`, contact configured | title "Mentions légales et confidentialité", updated line, the rights bullets rectification/objection/death/banned and the terms moderation/notice each carry the `mailto:` link | No error expected |
| Legal page EN, contact unset | `GET /en/legal`, nothing configured | the same bullets read "write to the publisher" (no link), page 200 | No error expected |
| Deletion wording | either locale | no "anonymis" / "anonymised" anywhere on the page | No error expected |
| Sign-in panel, signed out | any page rendering the panel, `fr` | panel holds "En vous connectant, vous acceptez les conditions et la confidentialité." with links to `/fr/legal#legal-terms` and `/fr/legal#legal-privacy` | No error expected |
| Sign-in panel, signed in | signed-in player | panel absent (unchanged) | No error expected |
| Visibility label | public profile of a public player | "Visible par tous, même sans compte" / "Visible to everyone, even without an account" | No error expected |
| Report reasons | report dialog | first reason "Pseudo inapproprié" / "Inappropriate username" | No error expected |

</intent-contract>

## Code Map

- `app/views/pages/legal.html.erb` -- the page. h2 ids `legal-terms` and `legal-privacy` are the anchors to link. Add a `contact` local at the top (`@legal.contact_email ? mail_to(@legal.contact_email, class: "legal__link") : t(".contact_fallback")`) and reuse it in the existing `access_html` too only if behaviour is unchanged (keep `access_publisher`). Add `p.legal__updated` under the h1; `p.legal__acceptance` before the terms `<ol>`; terms list order: free, no_money, no_property, fair_play, moderation_html, notice_html, no_guarantee, changes, law (drop `content`). Privacy order: stored intro + list (steam, activity, moderation, settings, last_seen, technical), purposes intro + list (game, moderation, security, requests) + `p` no_automation, `p.legal__visibility`, cookies, nothing_else, services (unchanged structure), deletion, rights intro `p` + list (access as today, rectification_html, erasure, objection_html, death_html, banned_html, complaint_html).
- `app/frontend/styles/settings.css:216-303` -- the legal page styles; add `.legal__updated` (muted, `--font-label`) next to `.legal__title`.
- `app/views/shell/_sign_in_panel.html.erb` -- add under `SteamSignInComponent`, inside `.modal__body`, a `p.sign-in-panel__acceptance` built from `t("shell.sign_in_panel.acceptance_html", terms: link_to(...), privacy: link_to(...))`; give that body an extra class (e.g. `sign-in-panel__body`) so only this panel stacks its children. Update the header comment (it says the panel holds only title, image and close).
- `app/frontend/styles/shell.css:1110-1113` -- `.modal__body` is a centred row; add `.sign-in-panel__body` (column, centred, gap) and `.sign-in-panel__acceptance` (muted, small body font, centred text) with its links underlined in the accent colour, hover `--color-accent-hi` (mirror `.legal__link`). Keep the phone bottom-sheet rules (l.1288-1315) working.
- `config/locales/fr.yml:125-176`, `config/locales/en.yml:120-171` -- `pages.legal.*`; `shell.sign_in_panel` (fr:48, en:47); `public_profiles.show.visibility.public` (fr:510, en:498); `reports.reasons.inappropriate_name` (fr:955, en:934).
- Tests to update: `test/controllers/pages_controller_test.rb:543-615` (title strings at 550-551 and 572; `configure_legal` helper at 28 restores config), `test/controllers/public_profiles_controller_test.rb:425`, `test/controllers/reports_controller_test.rb:35`, `test/system/settings_test.rb:193` and `test/system/share_card_test.rb:135` (heading regexes still match "Mentions légales et confidentialité" / "Legal notice and privacy"; adjust only if needed).
- New coverage: `test/integration/shell_test.rb` (signed-out panel links, signed-in no panel) and `test/system/hub_test.rb` near l.176 (a visitor opens the panel and follows the terms link to `/en/legal#legal-terms`, then the legal page shows; use retrying matchers).

## Tasks & Acceptance

**Execution:**
- [x] `config/locales/fr.yml`, `config/locales/en.yml` -- write every key of Design Notes exactly; remove `pages.legal.terms.content` and `pages.legal.terms.moderation` (replaced by `moderation_html`) -- the reviewed copy.
- [x] `app/views/pages/legal.html.erb`, `app/frontend/styles/settings.css` -- render the new and renamed keys in the order of the Code Map -- the page says it.
- [x] `app/views/shell/_sign_in_panel.html.erb`, `app/frontend/styles/shell.css` -- the acceptance line with its two links -- terms accepted at sign-in.
- [x] `test/controllers/pages_controller_test.rb` -- update titles; add tests for the matrix rows "contact set" (FR: each of the six `%{contact}` lines has the `mailto:` link, the updated line shows) and "contact unset" (EN: they read "the publisher", no `mailto:`), and that neither locale's page contains "anonymis" -- matrix coverage.
- [x] `test/integration/shell_test.rb` -- signed out: the panel's acceptance line links `/fr/legal#legal-terms` and `/fr/legal#legal-privacy`; signed in: no panel -- sign-in panel rows.
- [x] `test/system/hub_test.rb` -- follow the terms link from the open panel to the legal page -- the panel's link works in a browser.
- [x] `test/controllers/public_profiles_controller_test.rb`, `test/controllers/reports_controller_test.rb` -- new label strings -- label rows.

**Acceptance Criteria:**
- Given a signed-out visitor on the hub, when they open the sign-in panel and follow "conditions"/"terms", then the legal page opens at its terms section in their locale.
- Given the legal page in French and in English, when read side by side, then they hold the same sentences.

## Design Notes

**Facts checked (keep the copy true to them):** cookies: the default cookie-store session (no expiry: until sign-out or browser close; holds the CSRF token) and the motion cookie (1 year, only once a choice is made); localStorage holds trade drafts and once-shown toasts, sessionStorage the history trail and the menu focus. Sentry (`send_default_pii = false`, sentry-ruby 7.1.0): URL without query string, request headers minus cookies and IP headers (so User-Agent, Referer, Accept-Language), `Sentry.set_user(id:)`; CSP `report_uri` points to Sentry, so the browser sends reports there directly. Deletion: `Accounts::DeletePlayer` clears steam_id, persona_name, last_seen_at, replaces the token; `Game::ReleasePlayer` deletes feed entries, daily bonus claims, goal rewards, packs, holdings, set completions, friend code, player state, and via `DropFriendsAndTrades` cancels open trades and deletes invitations and friendships (the review was wrong: invitations are erased); kept: the player row (creation date, settings), closed trades, first discoveries, weekly contributions, reports, moderation actions, the event store. Reports need a signed-in player; bans are made by staff only. Profile and feed are readable signed out and filtered by `Game::Visibility`; staff see every profile.

**French (`pages.legal`), new or changed keys only:**
- `title`: Mentions légales et confidentialité
- `updated`: Dernière mise à jour : 9 octobre 2026
- `contact_fallback`: l'éditeur
- `ownership.data`: Les noms, couvertures et descriptions des jeux viennent de Steam et restent la propriété de leurs ayants droit. Sur demande d'un ayant droit, le jeu concerné est retiré sans délai.
- `terms.acceptance`: En vous connectant avec Steam, vous acceptez ces conditions.
- `terms.no_property`: (current text) + " Aucune carte ne peut être vendue ou échangée contre de l'argent, dans gameble ou en dehors."
- `terms.moderation_html`: Les joueurs peuvent signaler un profil. Des modérateurs examinent chaque signalement et peuvent suspendre un compte qui enfreint ces règles. La décision est toujours prise par une personne. Le joueur suspendu peut en demander le motif et la contester en écrivant à %{contact}.
- `terms.notice_html`: Même sans compte gameble, vous pouvez signaler un contenu illicite ou demander le retrait d'un jeu dont vous détenez les droits : écrivez à %{contact} en indiquant l'adresse de la page et la raison de votre demande.
- `terms.no_guarantee`: Le service est gratuit et fourni tel quel. Il peut être interrompu pour maintenance ou modifié. S'il devait fermer définitivement, la fermeture serait annoncée sur le site au moins 30 jours à l'avance.
- `terms.changes`: Ces conditions peuvent évoluer. Une modification importante est annoncée dans le jeu avant de s'appliquer. La version en vigueur est celle de cette page.
- `privacy.stored.activity`: votre activité de jeu : cartes, boosters, échanges, amis et invitations, code ami, entrées du fil d'activité ;
- `privacy.stored.moderation`: les signalements que vous faites, ceux qui visent votre profil (leur auteur ne vous est pas communiqué) et les décisions de modération qui vous concernent, avec leur motif ;
- `privacy.stored.last_seen`: la date de création de votre compte et l'heure de votre dernière visite ;
- `privacy.stored.technical`: des données techniques : adresse IP et navigateur, dans les journaux du serveur et le suivi d'erreurs.
- `privacy.purposes.intro`: Pourquoi et sur quelle base :
- `privacy.purposes.game`: faire fonctionner votre compte et le jeu (collection, boosters, échanges, amis, profil, fil d'activité) : exécution des conditions d'utilisation que vous acceptez en vous connectant (art. 6.1.b du RGPD) ;
- `privacy.purposes.moderation`: modérer la communauté (signalements, bannissements, historique de modération) : intérêt légitime de l'éditeur à faire respecter les règles et à protéger les joueurs (art. 6.1.f) ;
- `privacy.purposes.security`: sécuriser le site et corriger les erreurs (journaux du serveur, limitation des abus, suivi d'erreurs, Cloudflare) : intérêt légitime à assurer la sécurité et le bon fonctionnement du service (art. 6.1.f) ;
- `privacy.purposes.requests`: répondre à vos messages et à vos demandes sur vos données : obligation légale (art. 6.1.c).
- `privacy.purposes.no_automation`: Aucune décision vous concernant n'est prise de façon automatisée.
- `privacy.visibility`: Votre profil est public par défaut : votre nom de profil, votre collection et vos entrées du fil d'activité sont visibles de tous, y compris des visiteurs non connectés. Vous pouvez le réserver à vos amis ou le rendre privé dans les paramètres. Les modérateurs de gameble peuvent consulter tout profil, quel que soit son réglage.
- `privacy.cookies`: gameble n'utilise que des cookies strictement nécessaires, exemptés de consentement : celui de la session, qui protège les formulaires et vous garde connecté jusqu'à la déconnexion ou la fermeture du navigateur, et celui qui retient votre choix d'animations réduites, pendant un an. Cloudflare peut y ajouter un cookie de sécurité qui filtre les robots. Le stockage de votre navigateur garde aussi vos brouillons d'échange et l'état de l'interface, sur votre appareil seulement. Aucun traceur publicitaire ni de mesure d'audience.
- `privacy.services.sentry`: Sentry (Functional Software, Inc.) reçoit les erreurs techniques : l'adresse de la page et celle d'où vous venez, le navigateur utilisé et sa langue, et votre identifiant interne de joueur, jamais votre nom ni votre identifiant Steam. Votre navigateur lui envoie aussi directement les rapports de sécurité de la page ;
- `privacy.deletion`: Quand vous supprimez votre compte, votre identifiant Steam, votre nom de profil, l'heure de votre dernière visite, votre collection, vos boosters, vos amitiés, vos invitations, votre code ami et vos entrées du fil d'activité sont effacés, vos échanges en cours sont annulés et votre profil disparaît. Ce qui concerne aussi d'autres joueurs, la communauté ou la modération (échanges passés, premières découvertes, contributions à l'objectif communautaire, signalements, historique de modération, journal des actions du jeu) est conservé sans votre identifiant Steam ni votre nom.
- `privacy.rights.intro`: Vous pouvez accéder à vos données, les faire rectifier ou effacer, en limiter le traitement, vous opposer à un traitement fondé sur l'intérêt légitime et en recevoir une copie réutilisable. Vous pouvez aussi indiquer ce que deviennent vos données après votre décès. Nous répondons sous un mois.
- `privacy.rights.rectification_html`: rectification : votre nom de profil suit celui de Steam et il est relu à chaque connexion ; pour le reste, écrivez à %{contact} ;
- `privacy.rights.objection_html`: opposition : rendez votre profil privé dans les paramètres, ou écrivez à %{contact} ;
- `privacy.rights.death_html`: après votre décès : indiquez à %{contact} à qui vos données doivent être communiquées ou si elles doivent être effacées ;
- `privacy.rights.banned_html`: compte suspendu : il ne peut plus se connecter ; écrivez à %{contact} pour obtenir vos données, le motif de la suspension ou l'effacement de votre compte ;
- `support.text`: gameble est gratuit et le restera. Si le jeu vous plaît, vous pouvez aider à payer son hébergement. Les dons sont facultatifs et ne donnent aucun avantage dans le jeu. Ils passent par Buy Me a Coffee, selon ses propres conditions. L'éditeur reçoit ce que vous choisissez d'y indiquer (nom, message).
- `shell.sign_in_panel.acceptance_html`: En vous connectant, vous acceptez les %{terms} et la %{privacy}. — `terms`: conditions — `privacy`: confidentialité
- `public_profiles.show.visibility.public`: Visible par tous, même sans compte — `reports.reasons.inappropriate_name`: Pseudo inapproprié

**English, same keys:** title "Legal notice and privacy"; updated "Last updated: 9 October 2026"; contact_fallback "the publisher"; ownership.data + " At a rights holder's request, the game concerned is removed without delay."; acceptance "By signing in with Steam, you accept these terms."; no_property + " No card may be sold or exchanged for money, in gameble or outside it."; moderation_html "Players can report a profile. Moderators review every report and may suspend an account that breaks these rules. The decision is always made by a person. A suspended player can ask for its reason and contest it by writing to %{contact}."; notice_html "Even without a gameble account, you can report illegal content or ask for the removal of a game whose rights you hold: write to %{contact} with the page's address and the reason for your request."; no_guarantee "The service is free and provided as is. It may be interrupted for maintenance or changed. Should it close for good, the closure would be announced on the site at least 30 days in advance."; changes "These terms may change. A significant change is announced in the game before it applies. The version in force is the one on this page."; then translate every remaining French line above literally, keeping "GDPR", "Article 6(1)(b)" style references, list items ending with ";" and the last with "."; acceptance_html "By signing in, you accept the %{terms} and the %{privacy}." with terms "terms" and privacy "privacy notice"; visibility.public "Visible to everyone, even without an account"; inappropriate_name "Inappropriate username".

## Verification

Run from `/home/teyermann/projets/gameble/.claude/worktrees/agent-a3b29fb222a9e79d5` with `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w722 CHROME_BIN=/usr/bin/chromium` (never another database).

**Commands:**
- `bin/rails test` -- expected: 0 failures, 0 errors
- `bin/rails test:system TEST="test/system/hub_test.rb test/system/settings_test.rb test/system/share_card_test.rb test/system/public_profile_test.rb test/system/moderation_test.rb"` -- expected: green
- `bundle exec i18n-tasks missing && bundle exec i18n-tasks unused` -- expected: nothing reported
- `bin/rubocop`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `npm run test:js` -- expected: clean

## Implementation Notes

- The existing controller test that asserted the sign-in panel holds no link now asserts its only links are the two legal anchors.
- `access_html` reuses the `contact` local inside its `if` branch; `access_publisher` stays for the unset case.
- The sign-in panel's header comment drops its DESIGN.md / EXPERIENCE.md references while being rewritten.
- Author fact relayed during the build (2026-10-09): Sentry's data is in Sentry's EU region. `privacy.services.sentry` now ends "Données hébergées dans l'Union européenne" / "Data hosted in the European Union", asserted in the French contact test. No transfer sentence is written (Cloudflare is not shown in front by the repo); the author also decided against a first-sign-in notice about the public profile, so none is added.

## Plan Change Log

## Review Triage Log

### 2026-10-09 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 1, false 2, maybe-false 0
- findings:
  - `[false]` `[reject]` `privacy.services.sentry` names an EU hosting region the plan's Never list forbids and the repo cannot back — the author confirmed during the build that Sentry's data is in Sentry's EU region (relayed by the coordinator, recorded in Implementation Notes); the sentence states that fact, so the claimed bad outcome (an unbacked claim) does not occur.
  - `[false]` `[reject]` the French contact test locks in the forbidden region sentence — same refutation: the sentence is the author's confirmed fact and the assertion guards it.
  - `[low]` `[patch]` `privacy.stored.technical` says the IP is kept in error tracking while the Sentry line omits the IP — true: server events carry no IP (`send_default_pii = false`) but the browser's CSP reports reach Sentry directly; the Sentry line's report sentence now ends "avec votre adresse IP" / "with your IP address" in both locales.

## Auto Run Result

- **Summary:** the legal page's privacy notice and terms rewritten from the 2026-10-09 legal review (draft copy for the author): purposes and legal bases, the full rights list (rectification, objection, death, banned player; restriction and portability in the intro, one-month answer), what is stored (moderation, friend code, invitations, creation date, IP and browser), what deletion erases and keeps (no "anonymised"), what Sentry receives (EU-hosted, author fact), the public-by-default profile and staff access, cookies with Cloudflare's possible security cookie, acceptance at sign-in, human moderation and appeal, takedown channel without an account, 30-day closure notice, no-sale and donations sentences, last-updated line; page title "Mentions légales et confidentialité"; the sign-in panel links the terms and privacy anchors; visibility and report-reason labels fixed.
- **Files:** `config/locales/{fr,en}.yml` (copy), `app/views/pages/legal.html.erb` + `app/frontend/styles/settings.css` (page lines, contact fallback), `app/views/shell/_sign_in_panel.html.erb` + `app/frontend/styles/shell.css` (acceptance line), tests in `test/controllers/{pages,public_profiles,reports}_controller_test.rb`, `test/integration/shell_test.rb`, `test/system/hub_test.rb`.
- **Review:** 1 patch (low), 0 deferred, 2 rejected as false (the EU region is the author's confirmed fact).
- **Follow-up review recommended:** false — one low patch only.
- **Verification:** `bin/rails test` 2064 runs, 0 failures; system tests (hub, settings, share_card, public_profile, moderation, feed) 172 runs, 0 failures; i18n-tasks missing/unused clean; rubocop, packwerk, zeitwerk clean; `npm run test:js` 210 passed.
- **Residual risks / for the author:** host name, address and country; `LEGAL_*` mandatory at boot; retention periods; controller identity; default visibility; ban reason shown to a banned player; IP purge in the event store (built separately); a legal link on every page; the Cloudflare/US transfer sentence (the repo does not show Cloudflare in front, yet the page still names it as in front). The French "vous acceptez ... la confidentialité" follows the requested wording, but a privacy notice is something one is informed of, not something one accepts.
