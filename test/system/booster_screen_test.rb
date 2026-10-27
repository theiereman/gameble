require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# The booster screen's server-rendered parts as the browser shows them: the
# faces of a hand shown again, the set celebration from its set tiers, the
# reserve's next booster or full reserve, and the title the screen is named
# by in each layout. Reduced motion is emulated in every test.
class BoosterScreenTest < ApplicationSystemTestCase
  include GamePacks
  include GameSets
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
    reduce_motion(true)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  teardown do
    reduce_motion(false)
  end

  def reduce_motion(on)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: on ? "reduce" : "" } ])
  end

  def on_phone
    resize_to(*PHONE)
  end

  def opened_pack
    create_pack(@player, cards: fixture_tier_ids, opened_at: 1.minute.ago)
  end

  # The opened `pack` reached the bronze tier of one ten-card theme per key.
  def reach_bronze(pack, *keys)
    members = fixture_tier_ids + unheld_cards(5)
    keys.each do |key|
      set_id = insert_theme(members, key:, season: catalog_seasons(:one))
      Game::SetTier.create!(player_id: @player.id, set_id:, tier: "bronze", reached_by: "pack", pack_id: pack.id, reached_at: Time.current, held: 5)
    end
  end

  def show_again(pack, celebration: false)
    visit booster_path(locale: :en, pack: pack.token, celebration: (1 if celebration))
    assert_selector ".booster[data-layout]"
  end

  test "a hand shown again deals each card's face at the row's size, and the phone's zoom at the large one" do
    pack = opened_pack
    show_again(pack)

    assert_selector ".booster__deal .booster-card[data-revealed]", count: 5
    (1..5).each { |position| assert_selector ".booster-card[data-position='#{position}'] .booster-card__front .card.card--m" }

    on_phone
    assert_selector ".booster[data-layout=phone] .booster-tray__slot--filled", count: 5
    first(".booster-tray__slot--filled").click
    assert_selector "dialog.booster-zoom[open] .booster-zoom__face .card.card--xl.card--rarity-common"
    click_button "Close"
    assert_no_selector "dialog.booster-zoom[open]"
  end

  test "a celebration of two results shows a banner for each in the panel, and steps through them on the phone" do
    pack = opened_pack
    reach_bronze(pack, "roguelike", "horror")
    show_again(pack, celebration: true)

    assert_selector ".booster__info .booster-celebration .booster-celebration__banner[data-tier=bronze]", count: 2
    assert_selector ".booster__info .booster-celebration__banner", text: /BRONZE TIER/, count: 2

    on_phone
    assert_selector ".booster-plate-band .booster-celebration--phone[data-still] .booster-celebration__banner", count: 1
    assert_selector ".booster-celebration__position", text: "1 / 2"
    first_set = find(".booster-celebration--phone .booster-celebration__set-name").text
    refute_empty first_set

    find(".booster-celebration__next[aria-label='Next result']").click
    assert_selector ".booster-celebration__position", text: "2 / 2"
    assert_selector ".booster-celebration--phone:not([data-still]) .booster-celebration__banner", count: 1
    assert_no_selector ".booster-celebration--phone .booster-celebration__set-name", text: first_set, exact_text: true

    find(".booster-celebration__next[aria-label='Next result']").click
    assert_selector ".booster-celebration__position", text: "1 / 2"
    assert_selector ".booster-celebration--phone .booster-celebration__set-name", text: first_set, exact_text: true, count: 1
  end

  test "a celebration of four results folds into one banner: the tiers reached, their marks and the highest set" do
    pack = opened_pack
    reach_bronze(pack, "roguelike", "horror", "cosy", "metroidvania")
    show_again(pack, celebration: true)

    within(".booster__info .booster-celebration") do
      assert_selector ".booster-celebration__banner[data-tier=folded][href='/en/library']", count: 1
      assert_selector ".booster-celebration__ribbon", text: /\A\d+ TIERS REACHED\z/
      assert_selector ".booster-celebration__mark[data-tier=bronze]", count: 1
      assert_selector ".booster-celebration__sub", text: /\AINCL\. .+ BRONZE\z/i
      assert_selector ".booster-celebration__sub .booster-celebration__set", text: /\S/
      assert_selector ".booster-celebration__hint", text: "IN PROGRESS"
    end

    on_phone
    within(".booster-plate-band .booster-celebration--phone") do
      assert_selector ".booster-celebration__banner[data-tier=folded] .booster-celebration__arrow", count: 1
      assert_no_selector ".booster-celebration__step"
    end
  end

  test "the reserve says when the next booster comes, in the panel and in the phone's strip" do
    create_pack(@player, available_at: 1.hour.ago)
    create_pack(@player, available_at: 2.hours.from_now)
    visit booster_path(locale: :en)

    assert_selector ".booster__info .booster__next:not(.booster__next--full)", text: /\A\+1 in \d/
    assert_selector ".booster__info .booster__next .booster__clock", text: /\d/
    assert_no_selector ".booster__info .booster__next--full"

    on_phone
    assert_selector ".booster-strip .booster-strip__next:not(.booster__next--full)", text: /\A\+1 in \d/
    assert_no_selector ".booster-strip .booster__next--full"
  end

  test "a full reserve says so in place of the next booster, in the panel and in the phone's strip" do
    Game::Reserve::FULL.times { |index| create_pack(@player, available_at: (index + 1).hours.ago) }
    create_pack(@player, available_at: 2.hours.from_now)
    visit booster_path(locale: :en)

    assert_selector ".booster__info .booster__next--full", text: "Reserve full"
    assert_no_selector ".booster__info .booster__next:not(.booster__next--full)"

    on_phone
    assert_selector ".booster-strip .booster__next--full", text: "Reserve full"
    assert_no_selector ".booster-strip .booster-strip__next:not(.booster__next--full)"
  end

  test "the screen is named by the panel's title in a row and by the strip's title on the phone" do
    create_pack(@player, available_at: 1.hour.ago)
    visit booster_path(locale: :en)

    assert_selector ".booster[data-layout=wide][aria-labelledby=booster-panel-title]"
    assert_selector "#booster-panel-title", text: "GRAND CATALOGUE"

    on_phone
    assert_selector ".booster[data-layout=phone][aria-labelledby=booster-title]"
    assert_equal "booster-title", find(".booster")["aria-labelledby"]
    assert_selector "#booster-title", text: "SEASON 1 · GRAND CATALOGUE"
  end

  test "on the phone, a hand shown again closes with the inventory hint" do
    show_again(opened_pack)
    on_phone

    assert_selector ".booster-plate-band__hint", text: "Capsule inventoried · +5 cards in the collection"
  end

  test "without a published season the canister names no season" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)
    create_pack(@player, available_at: 1.hour.ago)
    visit booster_path(locale: :en)

    assert_selector ".booster-canister[aria-label='Open the capsule, grand catalogue, 5 cards']"
    assert_no_selector ".booster-canister[aria-label*='Season']"
  end
end
