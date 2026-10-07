require "test_helper"

class PlayerStreamTagTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    @player = accounts_players(:player)
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in(player)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    post "/auth/steam", params: { origin: "/en" }
    follow_redirect!
    assert_equal player.id, session[:player_id]
  end

  def stream_source = css_select("turbo-cable-stream-source").sole

  test "a player's pages subscribe to their own stream in the page's locale" do
    sign_in @player

    { en: home_path(locale: :en), fr: friends_path(locale: :fr) }.each do |locale, path|
      get path

      source = stream_source
      assert_equal "PlayerStreamChannel", source["channel"]
      assert_equal PlayerStream.name(@player, locale), Turbo::StreamsChannel.verified_stream_name(source["signed-stream-name"])
    end
    assert_no_match @player.stream_key, response.body.remove(stream_source["signed-stream-name"]), "the key shows only signed"
  end

  test "a visitor's page subscribes to nothing" do
    get home_path(locale: :en)

    assert_select "turbo-cable-stream-source", 0
  end

  test "the back-office subscribes to nothing" do
    sign_in accounts_players(:moderator)

    get back_office_path(locale: :en)

    assert_response :success
    assert_select "turbo-cable-stream-source", 0
  end

  test "menu 03 and the tab hold the badge slots the stream fills" do
    sign_in @player

    get home_path(locale: :en)

    assert_select ".hub-menu a.menu-item[href='/en/trades'] #menu-trades-badge.stream-slot .menu-item__badge--zero", "0"
    assert_select ".tab-bar a.tab-bar__tab[href='/en/trades'] #tab-trades-badge.stream-slot", 1
    assert_select "#tab-trades-badge .tab-bar__badge", 0
  end

  test "the trades and Friends screens refresh on their signal, held back by a board in edition" do
    friend = accounts_players(:moderator)
    low, high = [ @player.id, friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    Game::Holding.create!(player_id: friend.id, card_season_id: catalog_card_seasons(:portal_one).id, quantity: 1, reserved: 0)
    Game::Holding.create!(player_id: @player.id, card_season_id: catalog_card_seasons(:rare_card_one).id, quantity: 1, reserved: 0)
    trade = Game::ProposeTrade.new.call(player: friend, recipient: @player, offer: { catalog_card_seasons(:portal_one).id => 1 },
      request: { catalog_card_seasons(:rare_card_one).id => 1 }).value!
    sign_in @player

    [ trades_path(locale: :en), trade_path(locale: :en, token: trade.token) ].each do |path|
      get path
      assert_select "section.trades[data-controller='live-refresh'][data-live-refresh-signal-value='trades-updated']", 1
    end

    get counter_trade_path(locale: :en, token: trade.token)
    assert_response :success
    assert_select "section.trades[data-controller='live-refresh'] .trade-board[data-trade-board-editing-value='true']", 1
    Game::CancelTrade.new.call(player: friend, trade_id: trade.id).value!
    get new_trade_path(locale: :en, friend: friend.token)
    assert_select "section.trades[data-controller='live-refresh'] .trade-board[data-trade-board-editing-value='true']", 1

    get friends_path(locale: :en)
    assert_select "section.friends[data-controller='live-refresh'][data-live-refresh-signal-value='friends-updated']", 1
  end
end
