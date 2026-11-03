require "application_system_test_case"
require_relative "../support/custom_sets"
require_relative "../support/game_packs"
require_relative "../support/game_sets"
require_relative "../support/holdings"
require_relative "../support/steam_sign_in"

# A player's goals mark every card of their sets with the numbered
# bookmark, hanging from the top of the card's art: in the grid, which
# OBJECTIFS narrows to a goal, in the albums, in the capsule once a card
# turns, in the card detail and on the goal sets' tiles; never on another
# player's collection, and no longer once the goal is removed.
class GoalBookmarksTest < ApplicationSystemTestCase
  include CustomSets
  include GamePacks
  include GameSets
  include Holdings
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @portal = catalog_card_seasons(:portal_one).id
    @common = catalog_card_seasons(:common_card_one).id
  end

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def add(player = @player, **aim) = Game::AddGoal.new.call(player:, **aim).value!

  def roguelike(members = [ @portal, @common ]) = insert_set(members, { complete: members.size }, key: "roguelike", params: { "theme" => "roguelike" })

  def slot(title) = find(".collection-grid > li.collection-slot", text: title.upcase)

  def box(element) = element.evaluate_script("(() => { const r = this.getBoundingClientRect(); return [ r.left, r.top ].map(Math.round) })()")

  def assert_hangs_from_the_art(card)
    art_left, art_top = box(card.find(".card__art"))
    eventually("the bookmarks should hang from the art's top edge, 4px in from its left") do
      box(card.find(".card__goals")) == [ art_left + 4, art_top ]
    end
  end

  test "the grid marks a goal's cards from the top of their art, owned or not; OBJECTIFS narrows to it; a removed goal leaves no mark" do
    roguelike
    hold(@player, @common)
    add(kind: "studio", key: "valve")
    add(kind: "theme", key: "roguelike")
    sign_in(@player)

    visit library_cards_path(locale: :en)
    portal = slot("Portal")
    assert_equal %w[1 2], portal.all(".card__goals .goal-bookmark").map(&:text)
    assert_selector ".collection-grid .card:not(.card--not-owned) .card__goals .goal-bookmark", text: "2", count: 1
    assert_hangs_from_the_art(portal.find(".card"))
    assert_equal "1", portal.find(".card__goals").evaluate_script("getComputedStyle(this).opacity")
    assert_equal "none", portal.find(".card__goals").evaluate_script("getComputedStyle(this).filter")

    find("a.filter-row__pastille[href='#filters-goals']").click
    assert_selector "dialog#filters-goals", visible: true
    within("dialog#filters-goals fieldset[data-group=goals]") { find(".filter-chip", text: "ROGUELIKE").click }
    assert_selector ".collection-grid > li.collection-slot", count: 2
    assert_selector "a.filter-row__pastille[href='#filters-goals'] .filter-row__count:not([hidden]) [data-pastille-number]", text: "1"
    assert_current_path(/goals%5B%5D=theme%3Aroguelike|goals\[\]=theme:roguelike/)

    Game::RemoveGoal.new.call(player: @player, kind: "studio", key: "valve").value!
    Game::RemoveGoal.new.call(player: @player, kind: "theme", key: "roguelike").value!
    visit library_cards_path(locale: :en)
    assert_selector ".collection-grid > li.collection-slot", count: 5
    assert_no_selector ".card__goals"
    assert_no_selector "fieldset[data-group=goals]"
  end

  test "a shared card carries its goal in another set's album, not in the goal's own album" do
    roguelike
    insert_set([ @portal ], { complete: 1 }, key: "horror", params: { "theme" => "horror" })
    add(kind: "theme", key: "roguelike")
    sign_in(@player)

    visit library_set_path(locale: :en, kind: "theme", key: "horror")
    assert_selector ".set-album__grid .card .card__goals .goal-bookmark.goal-tone--1", text: "1"

    visit library_set_path(locale: :en, kind: "theme", key: "roguelike")
    assert_selector ".set-album__grid .card", count: 2
    assert_no_selector ".set-album__grid .card__goals"
  end

  test "a capsule card of a goal shows its bookmark only once turned, and the restored capsule keeps it" do
    roguelike([ @portal, *unheld_cards(1) ])
    add(kind: "theme", key: "roguelike")
    pack = create_pack(@player, cards: fixture_tier_ids)
    sign_in(@player)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])

    visit booster_path(locale: :en)
    find(".booster-canister").click
    assert_selector ".booster-card[data-dealt]", count: 5, wait: 10
    assert_selector ".booster__state", text: /\AINVENTORY\z/
    assert_selector ".booster-card:nth-child(4) .card__goals", visible: :hidden
    assert_no_selector ".booster-card:nth-child(4) .card__goals", visible: :visible

    find(".booster-card:nth-child(4) .booster-card__hit").click
    assert_selector ".booster-card:nth-child(4)[data-revealed] .card__goals .goal-bookmark", text: "1", visible: :visible
    assert_selector ".booster-card:nth-child(4) .booster-card__hit[aria-label='Portal — Valve, 2007, Epic, goal 1: Roguelike. See the card.']"
    find(".booster-card:nth-child(1) .booster-card__hit").click
    assert_selector ".booster-card:nth-child(1)[data-revealed]"
    assert_no_selector ".booster-card:nth-child(1) .card__goals", visible: :all

    visit booster_path(locale: :en, pack: pack.token)
    assert_selector ".booster-card:nth-child(4) .card__goals .goal-bookmark", text: "1", visible: :all
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "" } ])
  end

  test "the card detail shows the large bookmarks and an OBJECTIFS row leading to the goal's album" do
    custom_set = create_custom_set(@player, card_ids: %i[portal common_card uncommon_card].map { catalog_cards(it).id })
    add(kind: "studio", key: "valve")
    add(custom_set: custom_set.token)
    sign_in(@player)

    visit card_path(locale: :en, slug: "portal")
    card = find(".card-detail__card .card.card--l")
    assert_equal %w[1 2], card.all(".card__goals .goal-bookmark.goal-bookmark--large").map(&:text)
    assert_hangs_from_the_art(card)
    within(".card-detail__fact--goals") do
      assert_selector "dt", text: "GOALS"
      assert_selector "a.card-detail__goal.goal-tone--1[aria-label='Goal 1: Valve']", text: "Valve"
      find("a.card-detail__goal.goal-tone--2[aria-label='Goal 2: Mes favoris']").click
    end
    assert_current_path custom_set_path(locale: :en, token: custom_set.token)
  end

  test "a trade board marks the cards of the viewer's goal from the top of their art on desktop and phone, and none without a goal" do
    friend = accounts_players(:moderator)
    low, high = [ @player.id, friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    hold(@player, @portal)
    hold(friend, @common)
    trade = Game::ProposeTrade.new.call(player: friend, recipient: @player, offer: { @common => 1 }, request: { @portal => 1 }).value!
    sign_in(@player)

    visit trade_path(locale: :en, token: trade.token)
    assert_selector ".trade-board .card", count: 2
    assert_no_selector ".trade-board .card__goals"

    add(custom_set: create_custom_set(@player, name: "Portals", card_ids: %i[portal uncommon_card legendary_card].map { catalog_cards(it).id }).token)
    add(custom_set: create_custom_set(@player, name: "Commons", card_ids: %i[common_card uncommon_card legendary_card].map { catalog_cards(it).id }).token)
    visit trade_path(locale: :en, token: trade.token)
    assert_selector ".trade-board .card__goals .goal-bookmark", count: 2
    own = find(".trade-side--own .card")
    assert_equal %w[1], own.all(".card__goals .goal-bookmark").map(&:text)
    assert_hangs_from_the_art(own)
    friends = find(".trade-side--friend .card")
    assert_equal %w[2], friends.all(".card__goals .goal-bookmark").map(&:text)
    assert_hangs_from_the_art(friends)

    resize_to(390, 844)
    visit trade_path(locale: :en, token: trade.token)
    assert_selector ".trade-board .card__goals .goal-bookmark", count: 2
    assert_hangs_from_the_art(find(".trade-side--own .card"))
  end

  test "another player's collection and album show no bookmark, though the viewer and the owner both aim at the set" do
    roguelike
    viewer = accounts_players(:moderator)
    hold(@player, @common)
    add(kind: "theme", key: "roguelike")
    add(viewer, kind: "theme", key: "roguelike")
    sign_in(viewer)

    visit brother_collection_path(locale: :en, token: @player.token)
    assert_selector ".collection-grid > li.collection-slot", count: 5
    assert_no_selector ".card__goals"
    assert_no_selector "fieldset[data-group=goals]", visible: :all

    visit brother_set_path(locale: :en, token: @player.token, kind: "theme", key: "roguelike")
    assert_selector ".set-album__grid .card", count: 2
    assert_no_selector ".card__goals"
  end

  test "a goal set's tile in EN COURS and in MES SETS carries the goal edge and bookmark, and names the goal" do
    insert_set([ @portal, @common, catalog_card_seasons(:uncommon_card_one).id ], { complete: 3 }, key: "roguelike", params: { "theme" => "roguelike" })
    custom_set = create_custom_set(@player)
    hold(@player, @portal)
    hold(@player, @common)
    add(custom_set: custom_set.token)
    add(kind: "theme", key: "roguelike")
    sign_in(@player)

    visit library_path(locale: :en)
    within(".custom-sets") do
      tile = find("a.set-tile.set-tile--goal.goal-tone--1")
      assert_selector ".set-tile__face--recto .set-tile__goal .goal-bookmark--large", text: "1"
      assert_equal "Mes favoris, custom set, goal 1, 1 card out of 3", tile.find(".visually-hidden", visible: :all).text(:all)
      assert_match(/\Argb\([^)]+\) 6px 0px 0px 0px inset/, tile.find(".set-tile__face--recto").evaluate_script("getComputedStyle(this).boxShadow"))
    end
    within("#set-entry-in-progress") do
      tile = find("a.set-tile.set-tile--goal.goal-tone--2")
      assert_selector ".set-tile__face--recto .set-tile__goal .goal-bookmark--large", text: "2"
      assert_match(/\ARoguelike, theme, goal 2, 2 cards out of 3/, tile.find(".visually-hidden", visible: :all).text(:all))
    end
  end
end
