require "test_helper"
require_relative "../../support/holdings"

class Game::RemoveFriendTest < ActiveSupport::TestCase
  include Holdings
  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @carol = accounts_players(:administrator)
    @portal = catalog_card_seasons(:portal_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
    @soldier = catalog_card_seasons(:common_card_one).id
    [ [ @alice, @bob ], [ @alice, @carol ] ].each { |pair| befriend(*pair) }
    hold(@alice, @portal, 3)
    hold(@bob, @depths, 2)
    hold(@carol, @soldier, 2)
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def holding(player, card_season_id) = Game::Holding.find_by(player_id: player.id, card_season_id:)
  def propose(from, to, offer, request) = Game::ProposeTrade.new.call(player: from, recipient: to, offer:, request:).value!
  def friends?(first, second) = Game::FriendshipBetween.call(first, second)
  def remove(player, friend) = Game::RemoveFriend.new.call(player:, friend:)
  def removals = Rails.configuration.event_store.read.of_type([ Game::FriendRemoved ]).to_a

  test "removing a friend ends the friendship for both and keeps the others" do
    assert_equal @bob, remove(@alice, @bob).value!

    assert_not friends?(@alice, @bob)
    assert_not friends?(@bob, @alice)
    assert_not_includes Game::FriendsOf.call(@bob), @alice
    assert friends?(@alice, @carol)
  end

  test "the open trade between them is cancelled and its copies released, whichever side proposed it; trades with others stay" do
    mine = propose(@alice, @bob, { @portal => 2 }, { @depths => 1 })
    with_carol = propose(@carol, @alice, { @soldier => 1 }, { @portal => 1 })

    remove(@alice, @bob).value!

    mine.reload
    assert_equal "cancelled", mine.status
    assert_not_nil mine.closed_at
    assert_equal [ 3, 0 ], holding(@alice, @portal).slice(:quantity, :reserved).values
    assert_predicate with_carol.reload, :open?
    assert_equal 1, holding(@carol, @soldier).reserved
    assert_equal [ mine.id ], removals.sole.data[:trade_ids]
  end

  test "a trade the friend proposed is cancelled too, and its copies released" do
    theirs = propose(@bob, @alice, { @depths => 2 }, { @portal => 1 })

    remove(@alice, @bob).value!

    assert_equal "cancelled", theirs.reload.status
    assert_equal [ 2, 0 ], holding(@bob, @depths).slice(:quantity, :reserved).values
  end

  test "an expired trade still open between them is cancelled as well" do
    trade = propose(@alice, @bob, { @portal => 1 }, { @depths => 1 })
    trade.update_columns(expires_at: 1.day.ago)

    remove(@alice, @bob).value!

    assert_equal "cancelled", trade.reload.status
    assert_equal 0, holding(@alice, @portal).reserved
  end

  test "one event names both players and no trade when none was open" do
    remove(@alice, @bob).value!

    event = removals.sole
    assert_equal({ player_id: @alice.id, friend_id: @bob.id, trade_ids: [] }, event.data.slice(:player_id, :friend_id, :trade_ids))
    assert_equal 1, Rails.configuration.event_store.read.stream(Game::Operation.stream_name(@alice.id)).of_type([ Game::FriendRemoved ]).count
  end

  test "a player who is not a friend, a missing one or oneself is refused and nothing changes" do
    stranger = Accounts::Player.create!(steam_id: "76561197960299001", persona_name: "Sam")
    trade = propose(@alice, @bob, { @portal => 1 }, { @depths => 1 })

    [ stranger, nil, Accounts::Player.new, @alice, "not a player" ].each do |friend|
      assert_equal Dry::Monads::Failure(:not_a_friend), remove(@alice, friend), friend.inspect
    end

    assert friends?(@alice, @bob)
    assert_predicate trade.reload, :open?
    assert_equal 1, holding(@alice, @portal).reserved
    assert_empty removals
  end

  test "a visitor or a banned player cannot remove a friend" do
    assert_equal Dry::Monads::Failure(:player_required), remove(nil, @bob)
    @alice.update_columns(banned_at: Time.current)
    assert_equal Dry::Monads::Failure(:player_required), remove(@alice, @bob)
    assert friends?(@alice, @bob)
  end

  test "a second removal of the same friend is refused" do
    remove(@alice, @bob).value!

    assert_equal Dry::Monads::Failure(:not_a_friend), remove(@bob, @alice)
    assert_equal 1, removals.size
  end

  test "after a removal an invitation by link goes through, and accepting makes them friends once more" do
    remove(@bob, @alice).value!

    invitation = Game::SendInvitation.new.call(player: @alice, recipient_token: @bob.token).value!
    assert_equal [ "pending", @alice.id, @bob.id ], [ invitation.status, invitation.sender_id, invitation.recipient_id ]
    Game::AcceptInvitation.new.call(player: @bob, token: invitation.token).value!

    assert friends?(@alice, @bob)
  end

  test "either player can invite the other again, and accepting makes them friends once more" do
    accepted = Game::Invitation.create!(sender_id: @bob.id, recipient_id: @alice.id, status: "accepted")
    remove(@alice, @bob).value!

    invitation = Game::SendInvitation.new.call(player: @bob, code: "7K2Q-F3NX").value!
    assert_equal "pending", invitation.status
    Game::AcceptInvitation.new.call(player: @alice, token: invitation.token).value!

    assert friends?(@alice, @bob)
    assert Game::Invitation.exists?(accepted.id)
  end

  test "the refusal reads in both languages" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) { assert_not_includes Game::RemoveFriend.failure_message(:not_a_friend), "Translation missing" }
    end
  end
end
