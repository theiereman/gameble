require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"

class CardTradeTest < ApplicationSystemTestCase
  include Holdings
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze

  setup do
    @hugo = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @hugo.update!(persona_name: "Hugo")
    @lea.update!(persona_name: "Lea")
    @portal = catalog_card_seasons(:portal_one)
    low, high = [ @hugo.id, @lea.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    hold(@lea, @portal.id, 1)
    mock_steam_sign_in(@hugo.steam_id)
  end

  test "on a phone a player opens a trade asking a friend for a missing card, then sends it" do
    window = page.driver.browser.manage.window
    original = window.size
    window.resize_to(*PHONE)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit card_season_path(slug: catalog_cards(:portal).slug, number: @portal.season.number, locale: :en)

    find("a.card-detail__trade").click
    assert_selector "dialog#card-trade-sheet", visible: true
    eventually("the sheet should be a modal dialog") { evaluate_script("document.getElementById('card-trade-sheet').matches(':modal')") }
    within("#card-trade-sheet") { assert_selector ".card-trade__name", text: "Lea" }
    find("#card-trade-sheet .card-trade__friend", text: "Lea").click

    assert_selector ".trade-board__title", text: "Trade with Lea"
    assert_selector ".trade-side--friend li[data-key]", count: 1
    assert_equal 0, Game::Trade.count

    click_on "Send the proposal"
    assert_text "Lea has 7 days to choose what they want in return."
    trade = Game::Trade.order(:id).last
    assert_equal [ @hugo.id, @lea.id ], [ trade.proposer_id, trade.recipient_id ]
    assert_empty Game::TradeItem.where(trade_id: trade.id, side: "offer")
  ensure
    window.resize_to(*original) if original
  end
end
