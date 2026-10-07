require "test_helper"
require_relative "../../support/game_packs"

# Accounts::DeletePlayer (CAP-14, AD-14) and the Game handler it triggers
# (Game::Handlers::PlayerDeleted, Game::ReleasePlayer): the record stays,
# anonymised; the Steam id is released; what the player held is gone; the
# other players are untouched.
class Accounts::DeletePlayerTest < ActiveSupport::TestCase
  include GamePacks

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
      codes: Game::FriendCode.where(player_id: player.id).count }
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

  test "what the player held is released; the weekly contribution and the state row stay; another player is untouched" do
    play(@player)
    play(@other)
    Game::CreatePlayerState.new.call(player: @player).value!
    before = game_rows(@other)
    assert game_rows(@player).values.all?(&:positive?), game_rows(@player).inspect

    assert delete.success?

    assert_equal({ packs: 0, holdings: 0, feed: 0, claims: 0, codes: 0 }, game_rows(@player))
    assert Game::WeeklyContribution.exists?(player_id: @player.id)
    assert Game::PlayerState.exists?(player_id: @player.id)
    assert_equal before, game_rows(@other)
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
    assert_equal 0, Game::Pack.where(player_id: @player.id).count
  end

  test "Game releases only a saved player" do
    assert_equal Dry::Monads::Failure(:player_required), Game::ReleasePlayer.new.call(player: nil)
    assert_equal Dry::Monads::Failure(:player_required), Game::ReleasePlayer.new.call(player: Accounts::Player.new)
  end
end
