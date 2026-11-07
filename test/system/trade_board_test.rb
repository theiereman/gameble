require "application_system_test_case"
require_relative "../support/steam_sign_in"

class TradeBoardTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include SteamSignIn

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

  test "the picker's filter sheet narrows the friend's cards to a genre or to a goal, its pastille counting them" do
    soldier = catalog_card_seasons(:common_card_one)
    Game::Holding.create!(player_id: @lea.id, card_season_id: soldier.id, quantity: 1, reserved: 0)
    Catalog::CardSeason.where(id: @depths).update_all(main_theme: "horror")
    Catalog::CardSeason.where(id: soldier.id).update_all(main_theme: "puzzle")
    goal_cards = [ soldier, catalog_card_seasons(:uncommon_card_one), catalog_card_seasons(:legendary_card_one) ].map(&:card_id)
    custom_set = Game::CreateCustomSet.new.call(player: @hugo, name: "Puzzles", card_ids: goal_cards).value!
    Game::AddGoal.new.call(player: @hugo, custom_set: custom_set.token).value!
    sign_in_hugo
    visit new_trade_path(locale: :en, friend: @lea.token)

    find(".trade-side--friend .trade-add").click
    within(".trade-picker") do
      assert_selector ".trade-pick", count: 2

      click_on "Filters"
      within("#trade-picker-filter-sheet") do
        check "Horror", allow_label_click: true
        assert_selector ".filter-sheet__status", text: "1 card shown."
      end
      assert_selector ".trade-pick", count: 1
      assert_selector ".trade-pick__toggle[aria-label^='Blue Depths,']"
      assert_selector ".filter-row__pastille .filter-row__count", text: "1"

      within("#trade-picker-filter-sheet") do
        uncheck "Horror", allow_label_click: true
        find("fieldset[data-for=friend] .filter-chip--goal").click
        find(".modal__close").click
      end
      assert_selector ".trade-pick", count: 1
      assert_selector ".trade-pick__toggle[aria-label^='Tin Soldier,']"

      click_on "Clear filters"
      assert_selector ".trade-pick", count: 2
      assert_no_selector ".filter-row__pastille .filter-row__count", visible: true
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
  end
end
