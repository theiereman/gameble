require "test_helper"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/steam_sign_in"

class TradePricesTest < ActionDispatch::IntegrationTest
  include Holdings
  include MarketSettings
  include SteamSignIn

  def sign_in_origin = "/en"

  setup do
    @hugo = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @hugo.update!(persona_name: "Hugo")
    @lea.update!(persona_name: "Lea")
    low, high = [ @hugo.id, @lea.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)

    @portal = catalog_card_seasons(:portal_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
    @hills = catalog_card_seasons(:uncommon_card_one).id
    @crown = catalog_card_seasons(:legendary_card_one).id
    hold(@hugo, @portal, 3)
    [ @depths, @hills, @crown ].each { hold(@lea, it, 1) }

    price!(@depths, 46_200, 5)
    price!(@hills, 9_400, 2)
    price!(@portal, 8_100, 5)
  end

  def price!(card_season_id, average, sales_used)
    Game::Market::EditionPrice.create!(card_season_id:, average:, sales_used:)
  end

  def from_lea
    Game::ProposeTrade.new.call(player: @lea, recipient: @hugo, offer: { @depths => 1, @hills => 1, @crown => 1 }, request: { @portal => 2 }).value!
  end

  def side_prices(side) = css_select(".trade-side--#{side}:not(.trade-side--editing) .trade-card__price").map { it.text.squish }

  def link_labels(side) = css_select(".trade-side--#{side}:not(.trade-side--editing) a.card-link").map { it["aria-label"] }

  def pick(side, key) = ".trade-pick[data-side='#{side}'][data-key='#{key}']"

  test "each card of a received trade shows its edition's average price or no sale, a stack one copy's price, and no total" do
    open_market!(first_opened_at: 1.day.ago)
    trade = from_lea
    sign_in @hugo

    get trade_path(token: trade.token, locale: :en)

    assert_response :success
    assert_equal [ "46,200", "9,400", "No sale" ], side_prices(:friend)
    assert_equal [ "8,100" ], side_prices(:own)
    assert_select ".trade-side--own .trade-card__quantity", /×2/
    assert_select ".trade-card__price .picoin-amount[aria-label='46,200 PiCoins']"
    assert_select ".trade-card__price .average-price--none", "No sale"
    assert_select ".average-price__few", 0
    assert_select ".trade-side .picoin-amount", 3, "one amount per priced card, no total"
    assert_select ".trade-card__price[aria-hidden='true']", 4
    labels = link_labels(:friend)
    assert labels[0].end_with?(", average price 46,200 PiCoins"), labels[0]
    assert labels[1].end_with?(", average price 9,400 PiCoins"), labels[1]
    assert labels[2].end_with?(", no sale"), labels[2]
    assert link_labels(:own).sole.end_with?(", average price 8,100 PiCoins")
  end

  test "the accessible name ends with the price in French" do
    open_market!(first_opened_at: 1.day.ago)
    trade = from_lea
    sign_in @hugo

    get trade_path(token: trade.token, locale: :fr)

    labels = link_labels(:friend)
    assert_match(/, prix moyen 46\p{Zs}200 PiCoins\z/, labels[0])
    assert_match(/, prix moyen 9\p{Zs}400 PiCoins\z/, labels[1])
    assert labels[2].end_with?(", sans vente"), labels[2]
  end

  test "a sent, a concluded and a closed trade show today's prices" do
    open_market!(first_opened_at: 1.day.ago)
    sent = Game::ProposeTrade.new.call(player: @hugo, recipient: @lea, offer: { @portal => 1 }, request: { @hills => 1 }).value!
    sign_in @hugo

    get trade_path(token: sent.token, locale: :en)
    assert_equal [ "9,400" ], side_prices(:friend)
    assert_equal [ "8,100" ], side_prices(:own)

    assert Game::DeclineTrade.new.call(player: @lea, trade_id: sent.id, revision: Game::Trade.find(sent.id).revision).success?
    get trade_path(token: sent.token, locale: :en)
    assert_select ".trade-chip--muted"
    assert_equal [ "9,400" ], side_prices(:friend)
    assert_equal [ "8,100" ], side_prices(:own)

    concluded = from_lea
    assert Game::AcceptTrade.new.call(player: @hugo, trade_id: concluded.id, revision: Game::Trade.find(concluded.id).revision).success?
    price!(@crown, 31_900, 4)
    get trade_path(token: concluded.token, locale: :en)
    assert_select ".trade-chip--lime"
    assert_equal [ "8,100" ], side_prices(:friend)
    assert_equal [ "46,200", "9,400", "31,900" ], side_prices(:own)
  end

  test "the counter board shows each edited card's price under its stepper, the picker each cell's price, and the line template an empty slot" do
    open_market!(first_opened_at: 1.day.ago)
    trade = from_lea
    sign_in @hugo

    get counter_trade_path(token: trade.token, locale: :en)

    assert_response :success
    assert_select ".trade-side--own.trade-side--editing li[data-key='portal--s1'] .stepper + .trade-card__price", "8,100"
    assert_select ".trade-side--friend.trade-side--editing li[data-key='blue-depths--s1'] .trade-card__price", "46,200"
    assert_select ".trade-side--friend.trade-side--editing li[data-key='green-hills--s1'] .trade-card__price", "9,400"
    assert_select ".trade-side--friend.trade-side--editing li[data-key='golden-crown--s1'] .trade-card__price", "No sale"
    assert_select ".trade-side--editing .trade-card__price[aria-hidden]", 0
    assert_select "template[data-trade-board-side-target='lineTemplate'] .trade-card__price[hidden]:empty", 2

    assert_select "#{pick(:friend, 'blue-depths--s1')} .trade-pick__foot .trade-pick__price[aria-hidden='true'] + .trade-pick__available", "1 available"
    assert_select "#{pick(:friend, 'blue-depths--s1')} .trade-pick__price", "46,200"
    assert_select "#{pick(:friend, 'green-hills--s1')} .trade-pick__price", "9,400"
    assert_select "#{pick(:friend, 'golden-crown--s1')} .trade-pick__price", "No sale"
    assert_select "#{pick(:own, 'portal--s1')} .trade-pick__price", "8,100"
    assert_select ".trade-pick .average-price__few", 0
    assert_select "#{pick(:friend, 'blue-depths--s1')} .trade-pick__toggle[aria-label$=?]", ", average price 46,200 PiCoins"
    assert_select "#{pick(:friend, 'green-hills--s1')} .trade-pick__toggle[aria-label$=?]", ", average price 9,400 PiCoins"
    assert_select "#{pick(:friend, 'golden-crown--s1')} .trade-pick__toggle[aria-label$=?]", ", no sale"
  end

  test "the draft board's picker cells carry their prices" do
    open_market!(first_opened_at: 1.day.ago)
    sign_in @hugo

    get new_trade_path(friend: @lea.token, locale: :en)

    assert_response :success
    assert_select "#{pick(:friend, 'blue-depths--s1')} .trade-pick__price", "46,200"
    assert_select "#{pick(:own, 'portal--s1')} .trade-pick__price", "8,100"
    assert_select "template[data-trade-board-side-target='lineTemplate'] .trade-card__price[hidden]", 2
  end

  test "the prices are read once for the whole board and picker" do
    open_market!(first_opened_at: 1.day.ago)
    trade = from_lea
    sign_in @hugo
    reads = 0
    counter = ->(*, payload) { reads += 1 if payload[:sql].include?("game_market_edition_prices") }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get counter_trade_path(token: trade.token, locale: :en)
    end

    assert_response :success
    assert_equal 1, reads
  end

  test "a suspended market keeps showing the prices" do
    close_market!(first_opened_at: 1.day.ago)
    trade = from_lea
    sign_in @hugo

    get trade_path(token: trade.token, locale: :en)

    assert_equal [ "46,200", "9,400", "No sale" ], side_prices(:friend)
  end

  test "before the market's first opening no price shows on the board, the edited lines or the picker" do
    trade = from_lea
    sign_in @hugo

    get trade_path(token: trade.token, locale: :en)
    assert_select ".average-price", 0
    assert_select ".trade-card__price", 0
    assert link_labels(:friend).none? { it.include?("price") || it.include?("sale") }

    get counter_trade_path(token: trade.token, locale: :en)
    assert_select ".average-price", 0
    assert_select ".trade-card__price", 0
    assert_select ".trade-pick__price", 0
    assert_select "template[data-trade-board-side-target='lineTemplate'] .trade-card__price", 0
    assert_select ".trade-pick__toggle[aria-label*='price']", 0

    get new_trade_path(friend: @lea.token, locale: :en)
    assert_select ".trade-pick__price", 0
  end
end
