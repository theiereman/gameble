require "test_helper"
require_relative "../../support/lock_races"

# A ban against a trade acceptance between the banned player and a friend,
# and against an invitation to or from the banned player.
# Each thread has its own connection, so the test commits for real; it uses
# players of its own and removes them afterwards.
class Accounts::BanPlayerConcurrencyTest < ActiveSupport::TestCase
  include LockRaces

  self.use_transactional_tests = false

  setup do
    @moderator = accounts_players(:moderator)
    @target = Accounts::Player.create!(steam_id: "76561197960380001")
    @friend = Accounts::Player.create!(steam_id: "76561197960380002")
    @portal = catalog_card_seasons(:portal_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
    low, high = [ @target.id, @friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    Game::Holding.create!(player_id: @target.id, card_season_id: @portal, quantity: 2)
    Game::Holding.create!(player_id: @friend.id, card_season_id: @depths, quantity: 2)
    @trade = Game::ProposeTrade.new.call(player: @target, recipient: @friend, offer: { @portal => 1 }, request: { @depths => 1 }).value!
  end

  teardown do
    ids = [ @target.id, @friend.id ]
    trades = Game::Trade.where(proposer_id: ids).or(Game::Trade.where(recipient_id: ids)).ids
    Game::FeedEntry.where(trade_id: trades).delete_all
    Game::TradeItem.where(trade_id: trades).delete_all
    Game::Trade.where(id: trades).delete_all
    Game::Friendship.where(low_player_id: ids).or(Game::Friendship.where(high_player_id: ids)).delete_all
    Game::Invitation.where(sender_id: ids).or(Game::Invitation.where(recipient_id: ids)).delete_all
    [ Game::Holding, Game::SetCompletion, Game::PlayerState, Game::FeedEntry, Game::WeeklyContribution ].each { |model| model.where(player_id: ids).delete_all }
    connection = ActiveRecord::Base.connection
    streams = ids.flat_map { |id| [ Game::Operation.stream_name(id), "Accounts::Player$#{id}" ] }
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE event_id IN (?)", event_ids ])) if event_ids.any?
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
    Accounts::ModerationAction.where(player_id: ids).delete_all
    Accounts::Player.where(id: ids).delete_all
  end

  def ban = -> { Accounts::BanPlayer.new.call(staff: @moderator, player: Accounts::Player.find(@target.id), reason: "Rude name") }

  def accept(friend = Accounts::Player.find(@friend.id))
    revision = Game::Trade.find(@trade.id).revision
    -> { Game::AcceptTrade.new.call(player: friend, trade_id: @trade.id, revision:) }
  end

  def reserved(player, card_season_id) = Game::Holding.find_by(player_id: player.id, card_season_id:)&.reserved

  test "an acceptance that commits first: the ban then finds the trade closed and drops the friendship" do
    acceptance, banning = first_holding_the_lock(accept, ban)

    assert acceptance.success?
    assert banning.success?
    assert_equal "accepted", @trade.reload.status
    assert_predicate @target.reload, :banned?
    assert_not Game::FriendshipBetween.call(@target, @friend)
    assert_equal 0, reserved(@target, @portal)
  end

  test "an acceptance that waits on the ban finds the trade cancelled" do
    friend = Accounts::Player.find(@friend.id)

    banning, acceptance = first_holding_the_lock(ban, accept(friend))

    assert banning.success?
    assert_equal Dry::Monads::Failure(:trade_not_open), acceptance
    assert_equal "cancelled", @trade.reload.status
    assert_equal 0, reserved(@target, @portal)
    assert_equal [ 2, 2 ], [ Game::Holding.find_by(player_id: @target.id, card_season_id: @portal).quantity,
      Game::Holding.find_by(player_id: @friend.id, card_season_id: @depths).quantity ]
  end

  def invitations_of_target = Game::Invitation.where(sender_id: @target.id).or(Game::Invitation.where(recipient_id: @target.id)).count

  test "an invitation to a player being banned waits on the ban, then finds no one" do
    stranger = Accounts::Player.find(accounts_players(:player).id)

    banning, invitation = first_holding_the_lock(ban, -> { Game::SendInvitation.new.call(player: stranger, recipient_token: @target.token) })

    assert banning.success?
    assert_equal Dry::Monads::Failure(:unknown_player), invitation
    assert_equal 0, invitations_of_target
  end

  test "an invitation sent by a player being banned waits on the ban, then is refused" do
    target = Accounts::Player.find(@target.id)

    banning, invitation = first_holding_the_lock(ban, -> { Game::SendInvitation.new.call(player: target, recipient_token: accounts_players(:player).token) })

    assert banning.success?
    assert_equal Dry::Monads::Failure(:player_required), invitation
    assert_equal 0, invitations_of_target
  end
end
