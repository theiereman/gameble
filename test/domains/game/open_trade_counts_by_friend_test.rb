require "test_helper"
require_relative "../../support/holdings"

class Game::OpenTradeCountsByFriendTest < ActiveSupport::TestCase
  include Holdings
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

  def propose(player, recipient, offer:, request:)
    Game::ProposeTrade.new.call(player:, recipient:, offer:, request:).value!
  end

  test "each friend counts the open trades with them, whoever proposed each" do
    propose(@alice, @bob, offer: { @one => 1 }, request: { @three => 1 })
    propose(@alice, @bob, offer: { @two => 1 }, request: { @three => 1 })
    propose(@carol, @alice, offer: { @three => 1 }, request: { @one => 1 })

    assert_equal({ @bob.id => 2, @carol.id => 1 }, Game::OpenTradeCountsByFriend.call(@alice))
    assert_equal({ @alice.id => 2 }, Game::OpenTradeCountsByFriend.call(@bob))
  end

  test "a closed trade is not counted, an expired one still open until swept is" do
    to_bob = propose(@alice, @bob, offer: { @one => 1 }, request: { @three => 1 })
    Game::CancelTrade.new.call(player: @alice, trade_id: to_bob.id).value!
    from_carol = propose(@carol, @alice, offer: { @three => 1 }, request: { @one => 1 })
    from_carol.update_columns(expires_at: 1.minute.ago)

    assert_equal({ @carol.id => 1 }, Game::OpenTradeCountsByFriend.call(@alice))
    assert_empty Game::OpenTradeCountsByFriend.call(nil)
  end
end
