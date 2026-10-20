require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/lock_races"

# Deleting an account against the operations that write a player's rows: the
# deletion locks the player's row, then releases the bank under the bank lock
# (Game::ReleasePlayer), and every bank operation re-checks the deletion once
# it holds that lock (Game::Operation#lock_bank); a sign-in re-reads the row
# it locked, an invitation both players. Whichever commits first, no row of
# the deleted player is left. Each thread has its own connection, so the
# test commits for real; it uses a player of its own and removes it, any
# player signed up again with its Steam id, and the rows a publication's job
# gave the fixture players.
class Game::DeletePlayerConcurrencyTest < ActiveSupport::TestCase
  include GamePacks
  include LockRaces

  self.use_transactional_tests = false

  STEAM_ID = "76561197960299878".freeze

  setup do
    @player = Accounts::Player.create!(steam_id: STEAM_ID, persona_name: "Dana")
    Game::FillBank.new.call(player: @player).value!
  end

  teardown do
    created = [ @player.id ] + Accounts::Player.where(steam_id: STEAM_ID).where.not(id: @player.id).pluck(:id)
    players = Accounts::Player.pluck(:id)
    Game::WeeklyGoal.where(week_start: Date.current.beginning_of_week).delete_all
    Game::Invitation.where(sender_id: players).or(Game::Invitation.where(recipient_id: players)).delete_all
    Game::FirstDiscovery.where(player_id: created).delete_all
    [ Game::FeedEntry, Game::DailyBonusClaim, Game::GoalReward, Game::SetTier, Game::Pack, Game::Holding,
      Game::WeeklyContribution ].each { |model| model.where(player_id: players).delete_all }
    [ Game::FriendCode, Game::PlayerState ].each { |model| model.where(player_id: created).delete_all }
    connection = ActiveRecord::Base.connection
    streams = players.map { |id| Game::Operation.stream_name(id) } + created.map { |id| "Accounts::Player$#{id}" }
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
    Accounts::Player.where(id: created).delete_all
  end

  # Every table Game::ReleasePlayer empties of the player's rows.
  def released = [ Game::Pack, Game::Holding, Game::FeedEntry, Game::DailyBonusClaim, Game::GoalReward, Game::SetTier,
    Game::AchievementUnlock, Game::PlayerState, Game::FriendCode ]

  def leftovers = released.to_h { |model| [ model.name, model.where(player_id: @player.id).count ] }

  def none_left = released.to_h { |model| [ model.name, 0 ] }

  def delete_player = -> { Accounts::DeletePlayer.new.call(player: Accounts::Player.find(@player.id)) }

  # The opening's player is read before the deletion, as a request would.
  def open_pack(player = Accounts::Player.find(@player.id)) = -> { Game::OpenPack.new.call(player:) }

  def collect_bonus(player = Accounts::Player.find(@player.id)) = -> { Game::CollectDailyBonus.new.call(player:) }

  def heal(player = Accounts::Player.find(@player.id)) = -> { Game::HealBank.new.call(player:) }

  def invite(sender, **recipient) = -> { Game::SendInvitation.new.call(player: sender, **recipient) }

  def invitations_left = Game::Invitation.where(sender_id: @player.id).or(Game::Invitation.where(recipient_id: @player.id)).count

  def friend = Accounts::Player.find(accounts_players(:player).id)

  def shorten_bank(by: 3)
    Game::Pack.where(id: Game::Pack.bank(@player.id).limit(by).select(:id)).delete_all
  end

  test "an opening that commits first: the deletion, waiting on the bank lock, then removes its rows" do
    opening, deletion = first_holding_the_lock(open_pack, delete_player)

    assert opening.success?
    assert deletion.success?
    assert_predicate @player.reload, :deleted?
    assert_equal none_left, leftovers
  end

  test "a daily bonus that commits first: the deletion, waiting on the bank lock, then removes its pack and claim" do
    Game::OpenPack.new.call(player: @player).value!

    bonus, deletion = first_holding_the_lock(collect_bonus, delete_player)

    assert bonus.success?
    assert deletion.success?
    assert_equal none_left, leftovers
  end

  test "a heal that commits first: the deletion, waiting on the bank lock, then removes the healed packs" do
    shorten_bank

    healing, deletion = first_holding_the_lock(heal, delete_player)

    assert_equal Dry::Monads::Success(3), healing
    assert deletion.success?
    assert_equal none_left, leftovers
  end

  test "an opening that waits on the deletion's bank lock writes nothing" do
    player = Accounts::Player.find(@player.id)

    deletion, opening = first_holding_the_lock(delete_player, open_pack(player))

    assert deletion.success?
    assert_equal Dry::Monads::Failure(:player_required), opening
    assert_equal none_left, leftovers
  end

  test "a daily bonus, a fill, a heal or a goal reward that waits on the deletion writes nothing, not even a new bank" do
    week = Date.current.beginning_of_week
    Game::WeeklyGoal.create!(week_start: week, total: 1, target: 1)
    Game::WeeklyContribution.create!(player_id: @player.id, week_start: week, openings: 1)
    operations = {
      Game::CollectDailyBonus => {}, Game::FillBank => {}, Game::HealBank => {}, Game::GrantGoalReward => { week_start: week }
    }
    operations.each_with_index do |(operation, arguments), index|
      @player.update_columns(steam_id: "7656119796029#{9880 + index}", deleted_at: nil) if index.positive?
      player = Accounts::Player.find(@player.id)

      deletion, result = first_holding_the_lock(delete_player, -> { operation.new.call(player:, **arguments) })

      assert deletion.success?, operation.name
      assert_equal Dry::Monads::Failure(:player_required), result, operation.name
      assert_equal none_left, leftovers, operation.name
    end
  end

  test "the publication's job reaching a player being deleted skips them unreported and fills the others" do
    shorten_bank

    deletion, = first_holding_the_lock(delete_player, -> { assert_no_error_reported { Game::HealBanksJob.perform_now } })

    assert deletion.success?
    assert_equal none_left, leftovers
    %i[player moderator administrator].each { |name| assert_equal 10, Game::Pack.bank(accounts_players(name).id).count, name }
  end

  test "a sign-in with the Steam id being deleted leaves the deleted record nameless and signs up a new player" do
    deletion, signed_in = first_holding_the_lock(delete_player, -> { Accounts::SignIn.new.call(steam_id: STEAM_ID, persona_name: "Gabe") })

    assert deletion.success?
    assert_equal [ nil, nil ], @player.reload.values_at(:steam_id, :persona_name)
    newcomer = signed_in.value!.reload
    assert_not_equal @player.id, newcomer.id
    assert_equal [ STEAM_ID, "Gabe" ], newcomer.values_at(:steam_id, :persona_name)
    assert_equal 10, Game::Pack.bank(newcomer.id).count
    assert_equal none_left, leftovers
  end

  test "an invitation by friend code to a player being deleted waits, then finds no one" do
    Game::CreateFriendCode.new.call(player: @player)
    code = Game::FriendCode.where(player_id: @player.id).pick(:code)

    deletion, invitation = first_holding_the_lock(delete_player, invite(friend, code:))

    assert deletion.success?
    assert_equal Dry::Monads::Failure(:unknown_code), invitation
    assert_equal 0, invitations_left
  end

  test "an invitation by link to a player being deleted waits, then finds no one" do
    deletion, invitation = first_holding_the_lock(delete_player, invite(friend, recipient_token: @player.token))

    assert deletion.success?
    assert_equal Dry::Monads::Failure(:unknown_player), invitation
    assert_equal 0, invitations_left
  end

  test "an invitation sent by a player being deleted waits, then is refused" do
    sender = Accounts::Player.find(@player.id)

    deletion, invitation = first_holding_the_lock(delete_player, invite(sender, recipient_token: accounts_players(:player).token))

    assert deletion.success?
    assert_equal Dry::Monads::Failure(:player_required), invitation
    assert_equal 0, invitations_left
  end

  test "a collection mark that waits on the deletion recreates no state row" do
    Game::CreatePlayerState.new.call(player: @player)
    player = Accounts::Player.find(@player.id)

    deletion, mark = first_holding_the_lock(delete_player, -> { Game::MarkCollectionSeen.new.call(player:, up_to: Time.current) })

    assert deletion.success?
    assert_equal Dry::Monads::Failure(:player_required), mark
    assert_not Game::PlayerState.exists?(player_id: @player.id)
  end

  test "a player-state backfill that waits on the deletion recreates no row" do
    player = Accounts::Player.find(@player.id)

    deletion, state = first_holding_the_lock(delete_player, -> { Game::CreatePlayerState.new.call(player:) })

    assert deletion.success?
    assert_equal Dry::Monads::Failure(:player_required), state
    assert_not Game::PlayerState.exists?(player_id: @player.id)
  end

  test "a friend-code backfill that waits on the deletion recreates no code" do
    player = Accounts::Player.find(@player.id)

    deletion, code = first_holding_the_lock(delete_player, -> { Game::CreateFriendCode.new.call(player:) })

    assert deletion.success?
    assert_equal Dry::Monads::Failure(:player_required), code
    assert_not Game::FriendCode.exists?(player_id: @player.id)
  end

  test "openings and a deletion started together leave no row of the deleted player" do
    3.times { Game::OpenPack.new.call(player: @player) }
    player = Accounts::Player.find(@player.id)

    results = together(open_pack(player), open_pack(player), delete_player)

    assert results.last.success?
    results.first(2).select(&:failure?).each { |result| assert_includes %i[player_required no_pack_available], result.failure }
    assert_equal none_left, leftovers
  end

  test "a deletion, an opening, a bonus and a heal started together leave no row of the deleted player" do
    # A short bank of two available packs and three scheduled ones: the heal
    # has packs to add, and the reserve never fills before the bonus.
    Game::Pack.where(player_id: @player.id).delete_all
    2.times { |index| create_pack(@player, available_at: (index + 1).minutes.ago) }
    3.times { |index| create_pack(@player, available_at: (index + 1).minutes.from_now) }
    player = Accounts::Player.find(@player.id)
    bank_operations = [ Game::OpenPack, Game::CollectDailyBonus, Game::HealBank ]

    deletion, *results = together(delete_player, *bank_operations.map { |operation| -> { operation.new.call(player:) } })

    assert deletion.success?
    assert_predicate @player.reload, :deleted?
    results.zip(bank_operations).each do |result, operation|
      assert result.success? || result == Dry::Monads::Failure(:player_required), "#{operation.name}: #{result.inspect}"
    end
    assert_equal none_left, leftovers
  end
end
