require "test_helper"
require_relative "../support/steam_sign_in"

class PlayerStreamTagTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
  end

  def stream_source = css_select("turbo-cable-stream-source[channel=PlayerStreamChannel]").sole

  def public_stream_names
    css_select("turbo-cable-stream-source:not([channel=PlayerStreamChannel])").map { Turbo::StreamsChannel.verified_stream_name(it["signed-stream-name"]) }
  end

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

  test "a visitor's page subscribes to no player's stream" do
    get library_cards_path(locale: :en)
    assert_select "turbo-cable-stream-source[channel=PlayerStreamChannel]", 0

    get how_it_works_path(locale: :en)
    assert_select "turbo-cable-stream-source", 0
  end

  test "the back-office subscribes to nothing" do
    sign_in accounts_players(:moderator)

    get back_office_path(locale: :en)

    assert_response :success
    assert_select "turbo-cable-stream-source", 0
  end

  test "menu 03 and the Trades tab hold the badge slots the stream fills, empty at zero" do
    sign_in @player

    get home_path(locale: :en)

    assert_select ".hub-menu a.menu-item[href='/en/trades'] #menu-trades-badge.stream-slot", 1
    assert_select "#menu-trades-badge .menu-item__badge, #menu-trades-badge .visually-hidden", 0
    assert_select ".tab-bar a.tab-bar__tab[href='/en/trades'] #tab-trades-badge.stream-slot", 1
    assert_select "#tab-trades-badge .tab-bar__badge", 0
  end

  test "menu 04 and the Friends tab hold the invitations badge slots" do
    Game::Invitation.create!(sender_id: accounts_players(:moderator).id, recipient_id: @player.id)
    Game::Invitation.create!(sender_id: @player.id, recipient_id: accounts_players(:administrator).id)
    sign_in @player

    get home_path(locale: :en)

    assert_select ".hub-menu a.menu-item[href='/en/friends'] #menu-friends-badge.stream-slot .menu-item__badge--friends[aria-hidden=true]", "1"
    assert_select "#menu-friends-badge .visually-hidden", "1 invitation waiting for your answer"
    assert_select ".tab-bar a.tab-bar__tab[href='/en/friends'] #tab-invitations-badge.stream-slot .tab-bar__badge--friends[aria-hidden=true]", "1"
    assert_select "#tab-invitations-badge .visually-hidden", "1 invitation waiting for your answer"
  end

  test "a player with no invitation to answer sees no count on menu 04 or the Friends tab" do
    Game::Invitation.create!(sender_id: @player.id, recipient_id: accounts_players(:moderator).id)
    sign_in @player

    get home_path(locale: :en)

    assert_select "#menu-friends-badge.stream-slot", 1
    assert_select "#menu-friends-badge .menu-item__badge, #menu-friends-badge .visually-hidden", 0
    assert_select "#tab-invitations-badge.stream-slot", 1
    assert_select "#tab-invitations-badge .tab-bar__badge", 0
  end

  test "a visitor's page renders no invitations badge slot" do
    get library_cards_path(locale: :en)

    assert_select "#menu-friends-badge, #plus-friends-badge, #tab-invitations-badge", 0
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
