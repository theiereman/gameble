require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"

# A friend's answer to a proposal reaches the proposer's bell, and opening the
# trade takes it away for good, on every browser of the player.
class TradeUpdatesTest < ApplicationSystemTestCase
  include Holdings
  include SteamSignIn

  setup do
    @hugo = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @lea.update!(persona_name: "Lea")
    low, high = [ @hugo.id, @lea.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    @portal = catalog_card_seasons(:portal_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
    hold(@hugo, @portal, 2)
    hold(@lea, @depths, 1)
  end

  def sign_in
    mock_steam_sign_in(@hugo.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit home_path(locale: :en)
  end

  def update_line(trade) = "#bell-items a[href='/en/trades/#{trade.token}']"

  test "a declined proposal shows in the bell until the trade is opened, also in a fresh browser" do
    trade = Game::ProposeTrade.new.call(player: @hugo, recipient: @lea, offer: { @portal => 1 }, request: { @depths => 1 }).value!
    Game::DeclineTrade.new.call(player: @lea, trade_id: trade.id, revision: Game::Trade.find(trade.id).revision).value!
    sign_in

    assert_selector update_line(trade), text: /Lea declined your trade\./, visible: :all
    find(".bell__button").click
    assert_selector "#bell-panel:popover-open"
    within("#bell-panel") { click_link href: "/en/trades/#{trade.token}" }

    assert_current_path "/en/trades/#{trade.token}"
    assert_no_selector update_line(trade), visible: :all
    eventually("opening the trade should record one view") { Game::TradeView.where(player_id: @hugo.id).count == 1 }

    visit library_path(locale: :en)
    assert_no_selector update_line(trade), visible: :all

    Capybara.using_session("second device") do
      sign_in
      assert_selector "#bell-items .bell__line", visible: :all, minimum: 1
      assert_no_selector update_line(trade), visible: :all
    end
  end
end
