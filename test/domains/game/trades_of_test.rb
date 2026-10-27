require "test_helper"

class Game::TradesOfTest < ActiveSupport::TestCase
  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @carol = accounts_players(:administrator)
    @one = catalog_card_seasons(:portal_one).id
    @two = catalog_card_seasons(:common_card_one).id
    @three = catalog_card_seasons(:rare_card_one).id
    [ @bob, @carol ].each { befriend(@alice, it) }
    hold(@alice, @one, 3)
    hold(@alice, @two, 1)
    hold(@bob, @three, 2)
    hold(@carol, @three, 1)
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def hold(player, card_season_id, quantity)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:, reserved: 0)
  end

  def propose(player, recipient, offer:, request:)
    Game::ProposeTrade.new.call(player:, recipient:, offer:, request:).value!
  end

  test "a trade gets a 24-character token, never its id" do
    trade = propose(@alice, @bob, offer: { @one => 2 }, request: { @three => 1 })

    assert_match(/\A[1-9A-HJ-NP-Za-km-z]{24}\z/, trade.token)
  end

  test "the list holds the player's turn, the friend's turn and the recent ones, each seen from the player's side" do
    to_bob = propose(@alice, @bob, offer: { @one => 2, @two => 1 }, request: { @three => 1 })
    from_carol = propose(@carol, @alice, offer: { @three => 1 }, request: { @one => 1 })

    trades = Game::TradesOf.call(@alice)

    assert_equal [ from_carol.token ], trades.yours.map(&:token)
    assert_equal [ to_bob.token ], trades.theirs.map(&:token)
    assert_empty trades.recent
    assert_equal from_carol.token, trades.first.token

    mine = trades.theirs.first
    assert_equal @bob, mine.friend
    assert_equal [ [ @one, 2 ], [ @two, 1 ] ].sort, mine.own_side.map { [ it.card_season_id, it.quantity ] }
    assert_equal [ [ @three, 1 ] ], mine.friend_side.map { [ it.card_season_id, it.quantity ] }

    waiting = trades.yours.first
    assert_equal [ [ @three, 1 ] ], waiting.friend_side.map { [ it.card_season_id, it.quantity ] }
    assert_equal [ [ @one, 1 ] ], waiting.own_side.map { [ it.card_season_id, it.quantity ] }

    bob_view = Game::TradesOf.call(@bob)
    assert_equal [ to_bob.token ], bob_view.yours.map(&:token)
    assert_equal [ [ @one, 2 ], [ @two, 1 ] ].sort, bob_view.yours.first.friend_side.map { [ it.card_season_id, it.quantity ] }
  end

  test "finished trades are recent, with their outcome and end, newest first, for 14 days" do
    declined = propose(@alice, @bob, offer: { @one => 1 }, request: { @three => 1 })
    travel 1.hour
    Game::DeclineTrade.new.call(player: @bob, trade_id: declined.id, revision: Game::Trade.find(declined.id).revision).value!
    cancelled = propose(@alice, @carol, offer: { @one => 1 }, request: { @three => 1 })
    travel 1.hour
    Game::CancelTrade.new.call(player: @alice, trade_id: cancelled.id).value!
    accepted = propose(@alice, @bob, offer: { @two => 1 }, request: { @three => 1 })
    travel 1.hour
    Game::AcceptTrade.new.call(player: @bob, trade_id: accepted.id, revision: Game::Trade.find(accepted.id).revision).value!

    recent = Game::TradesOf.call(@alice).recent
    assert_equal [ accepted.token, cancelled.token, declined.token ], recent.map(&:token)
    assert_equal %i[concluded closed closed], recent.map(&:state)
    assert_equal %w[accepted cancelled declined], recent.map(&:outcome)
    assert_equal accepted.reload.closed_at, recent.first.ended_at

    travel 14.days - 30.minutes
    assert_equal [ accepted.token ], Game::TradesOf.call(@alice).recent.map(&:token)
    assert_equal declined.token, Game::TradesOf.find(@alice, declined.token).token, "an old trade is still found by its token"
  end

  test "an open trade past its expiry reads as expired and waits for nobody" do
    trade = propose(@carol, @alice, offer: { @three => 1 }, request: { @one => 1 })
    assert_equal 1, Game::TradesWaiting.call(@alice)

    travel Game::Trade::LIFETIME + 1.minute

    trades = Game::TradesOf.call(@alice)
    assert_empty trades.yours
    assert_equal [ [ :closed, "expired", trade.expires_at ] ], trades.recent.map { [ it.state, it.outcome, it.ended_at ] }
    assert_equal 0, Game::TradesWaiting.call(@alice)
  end

  test "the badge counts the trades waiting for the player's answer only" do
    propose(@alice, @bob, offer: { @one => 1 }, request: { @three => 1 })
    assert_equal 0, Game::TradesWaiting.call(@alice)
    assert_equal 1, Game::TradesWaiting.call(@bob)

    propose(@carol, @alice, offer: { @three => 1 }, request: { @one => 1 })
    assert_equal 1, Game::TradesWaiting.call(@alice)
    assert_equal 0, Game::TradesWaiting.call(nil)
  end

  test "a trade whose other party is banned is left out, and does not wait" do
    trade = propose(@carol, @alice, offer: { @three => 1 }, request: { @one => 1 })
    @carol.update!(banned_at: Time.current)

    assert Game::TradesOf.call(@alice).empty?
    assert_nil Game::TradesOf.find(@alice, trade.token)
    assert_equal 0, Game::TradesWaiting.call(@alice)
  end

  test "a trade is found by its token only by its parties" do
    trade = propose(@alice, @bob, offer: { @one => 1 }, request: { @three => 1 })

    assert_equal trade.id, Game::TradesOf.find(@bob, trade.token).id
    assert_nil Game::TradesOf.find(@carol, trade.token)
    assert_nil Game::TradesOf.find(nil, trade.token)
    assert_nil Game::TradesOf.find(@alice, "unknown")
    assert_nil Game::TradesOf.find(@alice, nil)
    assert Game::TradesOf.call(nil).empty?
  end

  test "free copies are the copies held minus those reserved in open trades" do
    propose(@alice, @bob, offer: { @one => 2 }, request: { @three => 1 })

    assert_equal({ @one => 1, @two => 1 }, Game::HeldCopies.call(@alice).transform_values(&:free))
    propose(@alice, @carol, offer: { @one => 1 }, request: { @three => 1 })
    assert_equal({ @one => 0, @two => 1 }, Game::HeldCopies.call(@alice).transform_values(&:free))
  end
end
