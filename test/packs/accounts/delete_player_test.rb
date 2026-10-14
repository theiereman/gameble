require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/game_trades"

# Accounts::DeletePlayer (CAP-14, AD-14) and the Game handler it triggers
# (Game::Handlers::PlayerDeleted, Game::ReleasePlayer): the record stays,
# anonymised; the Steam id is released; what the player held is gone; the
# other players are untouched.
class Accounts::DeletePlayerTest < ActiveSupport::TestCase
  include GamePacks
  include GameTrades

  setup do
    Game::DrawPool.reset!
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def delete(player = @player) = Accounts::DeletePlayer.new.call(player:)

  def deleted_events
    Rails.configuration.event_store.read.of_type(Accounts::PlayerDeleted).to_a
  end

  # A player with a bank, an opened pack (holdings, feed entries, a weekly
  # contribution), a daily bonus claim and a friend code.
  def play(player)
    Game::FillBank.new.call(player:).value!
    Game::OpenPack.new.call(player:).value!
    Game::CollectDailyBonus.new.call(player:)
    Game::CreateFriendCode.new.call(player:).value!
  end

  def game_rows(player)
    { packs: Game::Pack.where(player_id: player.id).count,
      holdings: Game::Holding.where(player_id: player.id).count,
      feed: Game::FeedEntry.where(player_id: player.id).count,
      claims: Game::DailyBonusClaim.where(player_id: player.id).count,
      codes: Game::FriendCode.where(player_id: player.id).count,
      rewards: Game::GoalReward.where(player_id: player.id).count,
      achievements: Game::AchievementUnlock.where(player_id: player.id).count,
      states: Game::PlayerState.where(player_id: player.id).count }
  end

  test "the record stays, anonymised: no Steam id, no name, a new token, deleted_at; PlayerDeleted carries its id only" do
    @player.update!(persona_name: "Gabe")
    token = @player.token

    result = travel_to(Time.utc(2026, 10, 7, 12)) { delete }

    assert_equal @player, result.value!
    @player.reload
    assert_nil @player.steam_id
    assert_nil @player.persona_name
    assert_not_equal token, @player.token
    assert_match(/\A[1-9A-HJ-NP-Za-km-z]{24}\z/, @player.token)
    assert_equal Time.utc(2026, 10, 7, 12), @player.deleted_at
    assert_predicate @player, :deleted?
    assert_nil Accounts::PlayerByToken.call(token)

    events = Rails.configuration.event_store.read.stream("Accounts::Player$#{@player.id}").of_type(Accounts::PlayerDeleted).to_a
    assert_equal 1, events.size
    assert_equal({ player_id: @player.id }, events.first.data)
  end

  test "what the player held is released, goal rewards, achievements and the state row included; the weekly contribution stays; another player is untouched" do
    play(@player)
    play(@other)
    [ @player, @other ].each { Game::GrantAchievementsJob.perform_now(it.id) }
    Game::CreatePlayerState.new.call(player: @player).value!
    Game::CreatePlayerState.new.call(player: @other).value!
    week = Game::WeeklyContribution.where(player_id: @player.id).pick(:week_start)
    Game::WeeklyGoal.create!(week_start: week, total: 1, target: 1)
    [ @player, @other ].each { |player| Game::GrantGoalReward.new.call(player:, week_start: week).value! }
    before = game_rows(@other)
    assert game_rows(@player).values.all?(&:positive?), game_rows(@player).inspect

    assert delete.success?

    assert_equal({ packs: 0, holdings: 0, feed: 0, claims: 0, codes: 0, rewards: 0, achievements: 0, states: 0 }, game_rows(@player))
    assert Game::WeeklyContribution.exists?(player_id: @player.id)
    assert_equal before, game_rows(@other)
  end

  test "the trades naming the player on either side leave the feed; a trade between others stays" do
    third = accounts_players(:administrator)
    portal = catalog_card_seasons(:portal_one).id
    rare = catalog_card_seasons(:rare_card_one).id
    conclude_trade(@player, @other, offer: { portal => 1 }, request: { rare => 1 })
    conclude_trade(@other, @player, offer: { portal => 1 }, request: { rare => 1 })
    kept = conclude_trade(@other, third, offer: { portal => 1 }, request: { rare => 1 })

    assert delete.success?

    assert_equal [ kept.id ], Game::FeedEntry.where(kind: "trade").pluck(:trade_id)
  end

  test "set completions are deleted; first discoveries stay, their pack forgotten, so the card is not discovered again" do
    common = fixture_tier_ids[0]
    Game::FirstDiscovery.where(card_season_id: common).delete_all
    create_pack(@player, cards: [ common ] * 5)
    Game::OpenPack.new.call(player: @player).value!
    create_pack(@player, cards: [ catalog_card_seasons(:portal_one).id ] * 5)
    Game::OpenPack.new.call(player: @player).value!
    create_pack(@other, cards: [ catalog_card_seasons(:portal_one).id ] * 5)
    Game::OpenPack.new.call(player: @other).value!
    assert Game::SetCompletion.exists?(player_id: @player.id)

    assert delete.success?

    assert_equal [ [ @player.id, nil ] ], Game::FirstDiscovery.where(card_season_id: common).pluck(:player_id, :pack_id)
    assert_not Game::SetCompletion.exists?(player_id: @player.id)
    assert Game::SetCompletion.exists?(player_id: @other.id)
    create_pack(@other, cards: [ common ] * 5)
    Game::OpenPack.new.call(player: @other).value!
    assert_empty game_events(@other, Game::CardDiscovered)
  end

  test "the last-seen and last-export times are erased, and a last-seen write queued before the deletion writes nothing" do
    @player.update_columns(last_seen_at: 10.minutes.ago, last_exported_at: 1.day.ago)
    delete

    assert_nil @player.reload.last_seen_at
    assert_nil @player.last_exported_at
    assert_equal Dry::Monads::Success(false), Accounts::NoteLastSeen.new.call(player_id: @player.id, at: Time.current)
    assert_nil @player.reload.last_seen_at
  end

  test "a player with no game deletes too" do
    assert delete.success?
    assert_predicate @player.reload, :deleted?
  end

  test "the Steam id signs up again as a new player, with a new bank" do
    steam_id = @player.steam_id
    play(@player)
    delete

    result = Accounts::SignIn.new.call(steam_id:)

    assert result.success?
    newcomer = result.value!
    assert_not_equal @player.id, newcomer.id
    assert_equal steam_id, newcomer.steam_id
    assert_not newcomer.deleted?
    assert_equal Game::Pack::BANK_SIZE, Game::Pack.where(player_id: newcomer.id).count
    assert_equal 0, Game::Pack.where(player_id: @player.id).count
  end

  test "no player, an unsaved, a banned or a deleted one is refused, and nothing is published" do
    assert_equal Dry::Monads::Failure(:player_required), delete(nil)
    assert_equal Dry::Monads::Failure(:player_required), delete(Accounts::Player.new)
    assert_equal Dry::Monads::Failure(:player_required), delete(accounts_players(:banned))
    assert_empty deleted_events

    delete
    assert_equal Dry::Monads::Failure(:player_required), delete
    assert_equal 1, deleted_events.size
  end

  test "a stale copy of a player deleted meanwhile is refused under the row lock" do
    stale = Accounts::Player.find(@player.id)
    delete

    assert_equal Dry::Monads::Failure(:player_required), delete(stale)
    assert_equal 1, deleted_events.size
  end

  test "a failure has a message in both locales" do
    %i[fr en].each do |locale|
      I18n.with_locale(locale) { assert_predicate Accounts::DeletePlayer.failure_message(:player_required), :present? }
    end
  end

  test "the database refuses a player without a Steam id who is not deleted, and a deleted one with a Steam id" do
    assert_raises(ActiveRecord::StatementInvalid) { @player.update_column(:steam_id, nil) }
    assert_raises(ActiveRecord::StatementInvalid) { @player.update_column(:deleted_at, Time.current) }
  end

  test "jobs walking the players skip a deleted one, banned included or not, and the backfills do not count it" do
    Game::CreateFriendCode.new.call(player: @player).value!
    Game::CreatePlayerState.new.call(player: @player).value!
    without_code = Game::BackfillFriendCodesJob.players_without_a_code
    without_row = Game::BackfillPlayerStatesJob.players_without_a_row

    delete

    [ false, true ].each do |include_banned|
      ids = []
      Accounts::PlayersInBatches.call(include_banned:) { |players| ids.concat(players.map(&:id)) }
      assert_not_includes ids, @player.id
      assert_includes ids, @other.id
    end
    assert_equal without_code, Game::BackfillFriendCodesJob.players_without_a_code
    assert_equal without_row, Game::BackfillPlayerStatesJob.players_without_a_row
  end

  test "every bank operation refuses a deleted player" do
    delete

    [ Game::OpenPack, Game::CollectDailyBonus, Game::FillBank, Game::HealBank ].each do |operation|
      assert_equal Dry::Monads::Failure(:player_required), operation.new.call(player: @player), operation.name
    end
    assert_equal Dry::Monads::Failure(:player_required), Game::GrantGoalReward.new.call(player: @player, week_start: Date.current.beginning_of_week)
    assert_equal 0, Game::Pack.where(player_id: @player.id).count
  end

  test "Game releases only a saved player" do
    assert_equal Dry::Monads::Failure(:player_required), Game::ReleasePlayer.new.call(player: nil)
    assert_equal Dry::Monads::Failure(:player_required), Game::ReleasePlayer.new.call(player: Accounts::Player.new)
  end
end
