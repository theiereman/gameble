require "test_helper"

class Game::OpenTradesByFriendTest < ActiveSupport::TestCase
  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @carol = accounts_players(:administrator)
    @one = catalog_card_seasons(:portal_one).id
    @three = catalog_card_seasons(:rare_card_one).id
    [ @bob, @carol ].each { befriend(@alice, it) }
    hold(@alice, @one, 3)
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

  test "each friend with a trade in progress maps to that trade's token, whoever proposed it" do
    to_bob = propose(@alice, @bob, offer: { @one => 1 }, request: { @three => 1 })
    from_carol = propose(@carol, @alice, offer: { @three => 1 }, request: { @one => 1 })

    assert_equal({ @bob.id => to_bob.token, @carol.id => from_carol.token }, Game::OpenTradesByFriend.call(@alice))
    assert_equal({ @alice.id => to_bob.token }, Game::OpenTradesByFriend.call(@bob))
  end

  test "a closed or expired trade is not in progress" do
    to_bob = propose(@alice, @bob, offer: { @one => 1 }, request: { @three => 1 })
    Game::CancelTrade.new.call(player: @alice, trade_id: to_bob.id).value!
    from_carol = propose(@carol, @alice, offer: { @three => 1 }, request: { @one => 1 })

    assert_equal({ @carol.id => from_carol.token }, Game::OpenTradesByFriend.call(@alice))
    assert_empty Game::OpenTradesByFriend.call(@alice, now: Game::Trade.find_by(token: from_carol.token).expires_at)
    assert_empty Game::OpenTradesByFriend.call(nil)
  end
end
