require "application_system_test_case"
require_relative "../support/steam_sign_in"

class TradeBoardTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include SteamSignIn

  PAGE_PROBE = 40

  setup do
    @hugo = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @lea.update!(persona_name: "Lea")
    low, high = [ @hugo.id, @lea.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    @portal = catalog_card_seasons(:portal_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
    Game::Holding.create!(player_id: @hugo.id, card_season_id: @portal, quantity: 2, reserved: 0)
    Game::Holding.create!(player_id: @lea.id, card_season_id: @depths, quantity: 1, reserved: 0)
  end

  def sign_in_hugo
    mock_steam_sign_in(@hugo.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  test "the picker and the placed lines show the card faces the board loads in batches" do
    sign_in_hugo
    visit new_trade_path(locale: :en, friend: @lea.token)

    find(".trade-side--friend .trade-add").click
    within(".trade-picker") do
      assert_selector ".trade-pick .card", text: /Blue Depths/i
      assert_no_selector ".trade-pick__face--pending"
      find(".trade-pick__toggle[aria-label^='Blue Depths,']").click
      click_on "Place", exact: true
    end

    within(".trade-side--friend.trade-side--editing") do
      assert_selector ".trade-card .card", text: /Blue Depths/i
      assert_no_selector ".trade-card__face--pending"
    end
  end

  test "a board a live refresh turns to the player's turn counters the friend's terms in place" do
    %i[common_card_one legendary_card_one].each do |card|
      Game::Holding.create!(player_id: @hugo.id, card_season_id: catalog_card_seasons(card).id, quantity: 1, reserved: 0)
    end
    trade = Game::ProposeTrade.new.call(player: @hugo, recipient: @lea, offer: { @portal => 1 }, request: { @depths => 1 }).value!
    sign_in_hugo
    visit trade_path(token: trade.token, locale: :en)
    assert_selector ".trade-board .trade-chip", text: /WAITING/i
    page.execute_script(<<~JS)
      window.faceRequests = []
      const send = window.fetch
      window.fetch = function (url, options) {
        if (String(url).includes("/trades/faces")) window.faceRequests.push(new URL(url, location.href).searchParams.getAll("keys[]"))
        return send.call(this, url, options)
      }
    JS
    assert_selector "turbo-cable-stream-source[connected]", visible: :all

    Game::CounterTrade.new.call(player: @lea, trade_id: trade.id, revision: Game::Trade.find(trade.id).revision,
      offer: { @depths => 1 }, request: { @portal => 2 }).value!
    perform_enqueued_jobs(only: PlayerStreamJob)

    assert_selector ".trade-board .trade-chip", text: /YOUR TURN/i
    within(".trade-board") { click_on "Counter" }

    assert_selector ".trade-board[data-editing]"
    assert_selector ".trade-side--own.trade-side--editing .trade-card__remove[aria-label='Remove Portal']"
    assert_selector ".trade-side--own.trade-side--editing .stepper[aria-valuenow='2']"
    assert_selector ".trade-side--friend.trade-side--editing .trade-card__remove[aria-label='Remove Blue Depths']"

    find(".trade-side--own .trade-add").click
    within(".trade-picker") { assert_selector ".trade-pick .card", count: 3 }
    assert_equal [ %w[golden-crown--s1 tin-soldier--s1] ], page.evaluate_script("window.faceRequests").map(&:sort), "one batch for the picker's missing faces"
  end

  def open_friend_picker
    sign_in_hugo
    visit new_trade_path(locale: :en, friend: @lea.token)
    find(".trade-side--friend .trade-add").click
    assert_selector ".trade-picker .trade-pick"
  end

  test "the picker shows its cards a page at a time and the next page when its end comes into view" do
    cards = Array.new(PAGE_PROBE) { |index| "paging-#{index}" }
    cards.each_with_index do |slug, index|
      card = Catalog::Card.create!(source_key: "src:#{slug}", slug:, release_date: Date.new(2020, 1, 1), image_url: "https://images.example.test/#{slug}.jpg",
        store_url: "https://store.example.test/#{slug}")
      %w[en fr].each { |locale| Catalog::CardText.create!(card:, locale:, title: "Paging #{index}") }
      season_id = Catalog::CardSeason.insert_all!([ { card_id: card.id, season_id: catalog_seasons(:one).id, prestige_score: 0.5, rating: 80.0,
        rarity: Catalog::Rarity::TIERS.key(:common), number: 100 + index } ], returning: :id).rows.flatten.sole
      Game::Holding.create!(player_id: @lea.id, card_season_id: season_id, quantity: 1, reserved: 0)
    end

    open_friend_picker

    assert_selector ".trade-pick", count: TradesHelper::FACES_PER_REQUEST
    page.execute_script("const body = document.querySelector('.trade-picker__body'); body.scrollTop = body.scrollHeight")
    assert_selector ".trade-pick", count: PAGE_PROBE + 1
  end

  test "on a phone the filters fold under their button" do
    resize_to(390, 844)
    open_friend_picker

    assert_selector ".trade-picker__fold[aria-expanded=false]"
    assert_selector ".trade-picker__groups--folded", visible: :all
    find(".trade-picker__fold").click
    assert_selector ".trade-picker__fold[aria-expanded=true]"
    assert_no_selector ".trade-picker__groups--folded"
    find(".trade-picker__fold").click
    assert_selector ".trade-picker__fold[aria-expanded=false]"
    assert_selector ".trade-picker__groups--folded", visible: :all
  end

  test "the comparison chips keep the friend's duplicates, what the player misses and what both own" do
    soldier = catalog_card_seasons(:common_card_one).id
    Game::Holding.create!(player_id: @lea.id, card_season_id: @portal, quantity: 1, reserved: 0)
    Game::Holding.create!(player_id: @lea.id, card_season_id: soldier, quantity: 1, reserved: 0)
    Game::Holding.find_by!(player_id: @lea.id, card_season_id: @depths).update!(quantity: 2)

    open_friend_picker
    assert_selector ".trade-pick", count: 3

    check "Their duplicates", allow_label_click: true
    assert_selector ".trade-pick", count: 1
    assert_selector ".trade-pick__toggle[aria-label^='Blue Depths,']"

    uncheck "Their duplicates", allow_label_click: true
    check "Missing from mine", allow_label_click: true
    assert_selector ".trade-pick", count: 2
    assert_no_selector ".trade-pick__toggle[aria-label^='Portal,']"

    uncheck "Missing from mine", allow_label_click: true
    check "We both own", allow_label_click: true
    assert_selector ".trade-pick", count: 1
    assert_selector ".trade-pick__toggle[aria-label^='Portal,']"
  end
end
