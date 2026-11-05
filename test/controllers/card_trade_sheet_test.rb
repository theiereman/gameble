require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"

class CardTradeSheetTest < ActionDispatch::IntegrationTest
  include Holdings
  include SteamSignIn

  def sign_in_origin = "/en"

  setup do
    @player = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @max = accounts_players(:administrator)
    @player.update!(persona_name: "Hugo")
    @lea.update!(persona_name: "Lea")
    @max.update!(persona_name: "Max")
    @portal = catalog_card_seasons(:portal_one)
    [ @lea, @max ].each { befriend(it) }
  end

  def befriend(friend)
    low, high = [ @player.id, friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def card_path(locale: :en) = card_season_path(slug: catalog_cards(:portal).slug, number: @portal.season.number, locale:)

  def portal_key = "#{catalog_cards(:portal).slug}--s#{@portal.season.number}"

  def opener_for(friend) = new_trade_path(friend: friend.token, ask: portal_key, locale: :en)

  def board_lines = css_select("[data-trade-board-target='line']").map { [ it["data-side"], it["data-key"], it["data-quantity"].to_i ] }

  def ask(friend) = Game::ProposeTrade.new.call(player: @player, recipient: friend, offer: {}, request: { @portal.id => 1 }).value!

  def trade_sides(trade)
    Game::TradeItem.where(trade_id: trade.id).group_by(&:side).transform_values { |items| items.to_h { [ it.card_season_id, it.quantity ] } }
      .reverse_merge("offer" => {}, "request" => {})
  end

  test "a missing card offers every friend who holds it, a single copy included" do
    hold(@lea, @portal.id, 1)
    hold(@max, @portal.id, 3)
    sign_in @player

    get card_path

    assert_response :success
    assert_select "a.card-detail__trade[href='#card-trade-sheet'][aria-haspopup=dialog]", text: /Trade/
    assert_select "dialog#card-trade-sheet[aria-labelledby]"
    assert_equal [ "Max", "Lea" ], css_select("#card-trade-sheet .card-trade__name").map { it.text.strip }
    assert_equal [ opener_for(@max), opener_for(@lea) ], css_select("#card-trade-sheet a.card-trade__friend").map { it["href"] }
    assert_no_match(/\b#{@lea.id}\b/, css_select("#card-trade-sheet").to_s)
  end

  test "a card the player owns has no trade button" do
    hold(@player, @portal.id, 1)
    hold(@lea, @portal.id, 2)
    sign_in @player

    get card_path

    assert_response :success
    assert_select "a.card-detail__trade", 0
    assert_select "#card-trade-sheet", 0
  end

  test "no friend holding the card, no button" do
    sign_in @player

    get card_path

    assert_select "a.card-detail__trade", 0
  end

  test "a visitor sees no trade button" do
    hold(@lea, @portal.id, 2)

    get card_path

    assert_select "a.card-detail__trade", 0
    assert_select "#card-trade-sheet", 0
  end

  test "a private friend and a reserved copy are not offered" do
    hold(@lea, @portal.id, 2)
    hold(@max, @portal.id, 1, reserved: 1)
    @lea.update_columns(visibility: "private")
    sign_in @player

    get card_path

    assert_select "a.card-detail__trade", 0
  end

  test "a friend already asked shows as plain text" do
    hold(@lea, @portal.id, 2)
    hold(@max, @portal.id, 1)
    ask(@lea)
    sign_in @player

    get card_path

    assert_select "#card-trade-sheet a.card-trade__friend", 1
    assert_select "#card-trade-sheet .card-trade__friend--asked", text: /Lea.*Already asked/m
  end

  test "reading the card writes nothing" do
    hold(@lea, @portal.id, 2)
    sign_in @player

    assert_no_difference -> { Game::Trade.count } do
      get card_path
    end
  end

  test "choosing a friend opens the trade board with the card asked for and sends nothing" do
    hold(@lea, @portal.id, 1)
    sign_in @player
    get card_path
    opener = css_select("#card-trade-sheet a.card-trade__friend").sole["href"]

    assert_no_difference -> { Game::Trade.count } do
      get opener
    end

    assert_response :success
    assert_equal "true", css_select("#trade-board").sole["data-trade-board-prefilled-value"]
    assert_equal [ [ "friend", portal_key, 1 ] ], board_lines
    assert_select "#trade-draft-form input[name=friend][value=?]", @lea.token
  end

  test "a card asked from its page is placed from a single copy, not a suggestion's duplicate rule" do
    hold(@lea, @portal.id, 1)
    sign_in @player

    get new_trade_path(friend: @lea.token, take: [ portal_key ], locale: :en)
    assert_empty board_lines

    get new_trade_path(friend: @lea.token, ask: { portal_key => "1" }, locale: :en)
    assert_empty board_lines
  end

  test "the board sends the trade only once the player sends it" do
    hold(@lea, @portal.id, 1)
    sign_in @player

    assert_difference -> { Game::Trade.count }, 1 do
      post trades_path(locale: :en), params: { friend: @lea.token, take: { portal_key => "1" } }
    end

    trade = Game::Trade.order(:id).last
    assert_equal [ @player.id, @lea.id ], [ trade.proposer_id, trade.recipient_id ]
    assert_equal({ "offer" => {}, "request" => { @portal.id => 1 } }, trade_sides(trade))
  end

  test "the sheet speaks French" do
    hold(@lea, @portal.id, 2)
    sign_in @player

    get card_path(locale: :fr)

    assert_select "a.card-detail__trade", text: /Échanger/
    assert_select "#card-trade-sheet .card-trade__copies", text: "2 exemplaires"
  end
end
