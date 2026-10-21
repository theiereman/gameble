# Walkthrough: the friendship action on a profile, and the Légendaire iridescence

Targets on `develop`:

- #199, commit `503b24e`: the identity band offers the viewer's one friendship action
- #220, commit `156e47c`: the Légendaire iridescence is subdued

Plan files: [the friendship action plan](../epic-screen-walkthrough/story-the-friendship-action-on-a-profile-plan.md) and [the iridescence plan](../epic-screen-walkthrough/bug-the-legendaire-iridescence-lets-the-card-s-content-show-thro-plan.md).

## #199: the friendship action on a profile

- [x] **Block 1: Intent.** The Intent section of the [friendship action plan](../epic-screen-walkthrough/story-the-friendship-action-on-a-profile-plan.md), pasted verbatim from that file:

  > **Problem:** A player viewing another player's public profile cannot act on the relation: the identity band shows only a greyed trade button to signed-out visitors and nothing to signed-in viewers, so befriending or trading with someone met on a profile means leaving for Amis and typing a code.
  >
  > **Approach:** The identity band shows the viewer's one action under the name, set by the relation (table below). A new `POST` on the profile sends the invitation through `Game::SendInvitation` (which already accepts a reverse pending invitation) and returns to the profile with a flash; a query names the relation.

- [x] **Block 2: Broad strokes.** Four entry points to open first:
  - [brother_invitations_controller.rb](../../../../app/controllers/brother_invitations_controller.rb): the one new write action, `create`, and its flash reporting.
  - [profile_relation.rb](../../../../packs/game/app/queries/game/profile_relation.rb): the query that names the viewer's relation to the owner.
  - [_action.html.erb](../../../../app/views/public_profiles/_action.html.erb): the case over the relation that renders the band's one action.
  - [public_profiles_controller.rb](../../../../app/controllers/public_profiles_controller.rb): `show`, where the relation is loaded for a signed-in viewer.

- [x] **Block 3: Relation query and its loading.** `Game::ProfileRelation.call(viewer, owner)` returns `:visitor` for no viewer, `:self` for the owner, `:friends` when `FriendshipBetween` finds a friendship, and otherwise reads the unanswered invitations between the two players and returns `:invited_by`, `:invited` or `:none`. `PublicProfilesController#show` calls `load_relation`, which skips a profile the viewer may not see and, for friends only, adds the open trade token.
  - [profile_relation.rb](../../../../packs/game/app/queries/game/profile_relation.rb)
  - [public_profiles_controller.rb:30](../../../../app/controllers/public_profiles_controller.rb) (the `load_relation` call in `show`) and [public_profiles_controller.rb:53](../../../../app/controllers/public_profiles_controller.rb) (the method)

- [x] **Block 4: The POST: controller, route and policy.** `BrotherInvitationsController#create` authorizes `:invitation, :create?`, resolves the owner by token, answers a hidden profile with the unavailable page, sends through `Game::SendInvitation`, and redirects to the profile. Its flash is set by `report_on_profile`, and a rate limit on the action redirects back to the profile when it trips.
  - [brother_invitations_controller.rb:9](../../../../app/controllers/brother_invitations_controller.rb) (`create`) and [brother_invitations_controller.rb:21](../../../../app/controllers/brother_invitations_controller.rb) (`report_on_profile`)
  - [routes.rb:44](../../../../config/routes.rb): `POST brothers/:token/invitation`, with the token constraint
  - [invitation_policy.rb](../../../../app/policies/invitation_policy.rb): `create?`

- [x] **Block 5: Rendering per relation.** The identity band in `_summary` renders the new `action` partial, which branches on the relation and renders one button, one disabled label, or the trades-closed line. `_profile` and `show` pass `relation` and `open_trade_token` down from the controller.
  - [_action.html.erb](../../../../app/views/public_profiles/_action.html.erb)
  - [_summary.html.erb](../../../../app/views/public_profiles/_summary.html.erb)
  - [_profile.html.erb](../../../../app/views/public_profiles/_profile.html.erb)
  - [show.html.erb](../../../../app/views/public_profiles/show.html.erb)

- [x] **Block 6: Locales.** Five new keys under `public_profiles.show` in each language: the action labels, their accessible names, and the pending label.
  - [en.yml:780](../../../../config/locales/en.yml)
  - [fr.yml:817](../../../../config/locales/fr.yml)

- [x] **Block 7: Tests.** A query test per relation, the controller's request tests for the POST, and a query-count change on the public profile page.
  - [profile_relation_test.rb](../../../../test/packs/game/profile_relation_test.rb)
  - [brother_invitations_controller_test.rb](../../../../test/controllers/brother_invitations_controller_test.rb)
  - [public_profiles_controller_test.rb](../../../../test/controllers/public_profiles_controller_test.rb)

- [x] **Block 8: Periphery.** The plan file that the commit adds next to the code, and the selector change in the reports test, which the new second button in the band made necessary.
  - [friendship action plan](../epic-screen-walkthrough/story-the-friendship-action-on-a-profile-plan.md)
  - [reports_controller_test.rb](../../../../test/controllers/reports_controller_test.rb)

## #220: the Légendaire iridescence

- [x] **Block 9: Intent.** The Intent section of the [iridescence plan](../epic-screen-walkthrough/bug-the-legendaire-iridescence-lets-the-card-s-content-show-thro-plan.md), pasted verbatim from that file:

  > **Problem:** The iridescent reflection on Légendaire cards (`.card__reflection--iridescence`) is strong enough that the card's art and text are hard to read (author, 2026-10-20, on staging).
  >
  > **Approach:** Tone down its opacity so the cover art, title and studio read clearly at every card size while the effect still marks a Légendaire; DESIGN.md records the new strength.

- [x] **Block 10: The one-value CSS change and the DESIGN.md wording.** The reflection layer's opacity in the stylesheet goes from `0.21` to `0.12`, still multiplied by the fresnel variable. The design reference's reflection paragraph is updated to name the new strength.
  - [card.css:547](../../../../app/frontend/styles/card.css)
  - [DESIGN.md:774](../ux-gameble/DESIGN.md)
