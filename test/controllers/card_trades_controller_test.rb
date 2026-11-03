require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"

class CardTradesControllerTest < ActionDispatch::IntegrationTest
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

  def trade_endpoint = card_trade_path(slug: catalog_cards(:portal).slug, number: @portal.season.number, locale: :en)

  def choose(friend) = post(trade_endpoint, params: { friend: friend.token })

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
    assert_select "#card-trade-sheet form[action=?]", trade_endpoint, 2
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

    assert_select "#card-trade-sheet form", 1
    assert_select "#card-trade-sheet .card-trade__friend--asked", text: /Lea.*Already asked/m
  end

  test "reading the card writes nothing" do
    hold(@lea, @portal.id, 2)
    sign_in @player

    assert_no_difference -> { Game::Trade.count } do
      get card_path
    end
  end

  test "choosing a friend sends a trade with the player's side empty" do
    hold(@lea, @portal.id, 1)
    sign_in @player

    assert_difference -> { Game::Trade.count }, 1 do
      choose @lea
    end

    trade = Game::Trade.order(:id).last
    assert_redirected_to trade_path(token: trade.token, locale: :en)
    assert_equal [ @player.id, @lea.id ], [ trade.proposer_id, trade.recipient_id ]
    assert_equal({ "offer" => {}, "request" => { @portal.id => 1 } }, trade_sides(trade))
    assert_equal "Lea has 7 days to choose what they want in return.", flash[:notice]
  end

  test "the friend reads the invitation to choose" do
    hold(@lea, @portal.id, 1)
    sign_in @player
    choose @lea
    token = Game::Trade.order(:id).last.token
    reset!
    sign_in @lea

    get trade_path(token:, locale: :en)

    assert_response :success
    assert_match(/lets you choose/, response.body)
  end

  test "a private friend is refused as on the board" do
    hold(@lea, @portal.id, 2)
    @lea.update_columns(visibility: "private")
    sign_in @player

    assert_no_difference -> { Game::Trade.count } do
      choose @lea
    end

    assert_redirected_to card_path
    assert_equal Game::Operation.failure_message(:friend_profile_private, name: "Lea"), flash[:alert]
    assert_nil flash[:trade_error]
  end

  test "a private player is refused" do
    hold(@lea, @portal.id, 2)
    @player.update_columns(visibility: "private")
    sign_in @player

    assert_no_difference -> { Game::Trade.count } do
      choose @lea
    end

    assert_redirected_to card_path
    assert_equal Game::Operation.failure_message(:own_profile_private), flash[:alert]
  end

  test "a friend who was already asked is refused" do
    hold(@lea, @portal.id, 2)
    ask(@lea)
    sign_in @player

    assert_no_difference -> { Game::Trade.count } do
      choose @lea
    end

    assert_redirected_to card_path
    assert_equal Game::Operation.failure_message(:trade_already_sent, name: "Lea"), flash[:alert]
  end

  test "a friend whose only copy is reserved is refused" do
    hold(@lea, @portal.id, 1, reserved: 1)
    sign_in @player

    assert_no_difference -> { Game::Trade.count } do
      choose @lea
    end

    assert_redirected_to card_path
    assert flash[:alert].present?
  end

  test "a friend who does not hold the card is refused" do
    sign_in @player

    assert_no_difference -> { Game::Trade.count } do
      choose @max
    end

    assert_redirected_to card_path
    assert flash[:alert].present?
  end

  test "someone who is not a friend is refused" do
    stranger = accounts_players(:banned)
    hold(stranger, @portal.id, 2)
    sign_in @player

    assert_no_difference -> { Game::Trade.count } do
      choose stranger
    end

    assert_redirected_to card_path
  end

  test "a visitor is sent to the landing" do
    assert_no_difference -> { Game::Trade.count } do
      choose @lea
    end

    assert_redirected_to home_path(locale: :en)
  end

  test "the sheet speaks French" do
    hold(@lea, @portal.id, 2)
    sign_in @player

    get card_path(locale: :fr)

    assert_select "a.card-detail__trade", text: /Échanger/
    assert_select "#card-trade-sheet .card-trade__copies", text: "2 exemplaires"
  end
end
