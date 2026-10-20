require "test_helper"

class Accounts::DeleteInactivePlayerTest < ActiveSupport::TestCase
  NO_LONGER_IDLE = Dry::Monads::Failure(:no_longer_idle)

  setup do
    @now = Time.current.change(usec: 0)
    @player = accounts_players(:player)
  end

  def delete(player = @player) = Accounts::DeleteInactivePlayer.new.call(player:, now: @now)

  # Last seen, and last changed, `ago`.
  def seen(player, ago) = player.update_columns(last_seen_at: @now - ago, updated_at: @now - ago)

  def deleted_events(player)
    Rails.configuration.event_store.read.stream("Accounts::Player$#{player.id}").of_type(Accounts::PlayerDeleted).to_a
  end

  def invitations_of(player)
    Game::Invitation.where(sender_id: player.id).or(Game::Invitation.where(recipient_id: player.id))
  end

  test "a player last seen three years and a second ago is deleted as they would delete themselves, their game released" do
    Game::FillBank.new.call(player: @player).value!
    Game::Invitation.create!(sender_id: @player.id, recipient_id: accounts_players(:moderator).id, status: "pending")
    Game::Invitation.create!(sender_id: accounts_players(:administrator).id, recipient_id: @player.id, status: "pending")
    seen(@player, 3.years + 1.second)

    assert_equal @player, delete.value!

    @player.reload
    assert_predicate @player, :deleted?
    assert_nil @player.steam_id
    assert_nil @player.last_seen_at
    assert_equal [ { player_id: @player.id } ], deleted_events(@player).map(&:data)
    assert_equal 0, Game::Pack.where(player_id: @player.id).count
    assert_empty invitations_of(@player)
  end

  test "a player last seen less than three years ago, or exactly three years ago, is refused and untouched" do
    [ 3.years - 1.second, 3.years ].each do |ago|
      seen(@player, ago)

      assert_equal NO_LONGER_IDLE, delete, ago.inspect
      assert_not_predicate @player.reload, :deleted?
      assert_not_nil @player.steam_id
    end
    assert_empty deleted_events(@player)
  end

  test "a player never seen counts from the last change to their account" do
    old = Accounts::Player.create!(steam_id: "76561197960390001", created_at: @now - 4.years, updated_at: @now - 3.years - 1.second)
    recent = Accounts::Player.create!(steam_id: "76561197960390002", created_at: @now - 4.years, updated_at: @now - 3.years + 1.second)

    assert delete(old).success?
    assert_predicate old.reload, :deleted?
    assert_equal NO_LONGER_IDLE, delete(recent)
    assert_not_predicate recent.reload, :deleted?
  end

  test "staff and banned players idle for four years are refused and keep their Steam id" do
    %i[moderator administrator banned].each do |name|
      player = accounts_players(name)
      seen(player, 4.years)

      assert_equal NO_LONGER_IDLE, delete(player), name
      assert_not_predicate player.reload, :deleted?, name
      assert_not_nil player.steam_id, name
    end
  end

  test "a player unbanned yesterday after a four-year ban, last seen four years ago, is not idle" do
    @player.update_columns(banned_at: @now - 4.years)
    seen(@player, 4.years)
    travel_to(@now - 1.day) { Accounts::UnbanPlayer.new.call(staff: accounts_players(:moderator), player: @player).value! }

    assert_equal NO_LONGER_IDLE, delete
    assert_not_predicate @player.reload, :deleted?
  end

  test "a moderator demoted yesterday, last seen four years ago, is not idle" do
    moderator = accounts_players(:moderator)
    seen(moderator, 4.years)
    travel_to(@now - 1.day) { Accounts::SetRole.new.call(steam_id: moderator.steam_id, role: "player").value! }

    assert_equal NO_LONGER_IDLE, delete(moderator.reload)
    assert_not_predicate moderator.reload, :deleted?
  end

  test "a player idle for four years who signs in is no longer idle" do
    seen(@player, 4.years)
    picked = Accounts::IdlePlayers.call(now: @now).find(@player.id)
    travel_to(@now) { Accounts::SignIn.new.call(steam_id: @player.steam_id).value! }

    assert_equal NO_LONGER_IDLE, delete(picked)
    assert_not_predicate @player.reload, :deleted?
  end

  test "a player seen after they were picked is refused under the row lock" do
    seen(@player, 4.years)
    picked = Accounts::IdlePlayers.call(now: @now).find(@player.id)
    @player.update_columns(last_seen_at: @now - 1.minute)

    assert_equal NO_LONGER_IDLE, delete(picked)
    assert_not_predicate @player.reload, :deleted?
    assert_empty deleted_events(@player)
  end

  test "an account deleted meanwhile is refused and published once" do
    seen(@player, 4.years)
    stale = Accounts::Player.find(@player.id)
    assert delete.success?

    assert_equal NO_LONGER_IDLE, delete(stale)
    assert_equal 1, deleted_events(@player).size
  end

  test "no player or an unsaved one is refused" do
    assert_equal Dry::Monads::Failure(:player_required), delete(nil)
    assert_equal Dry::Monads::Failure(:player_required), delete(Accounts::Player.new)
  end

  test "a failure has a message in both locales" do
    %i[fr en].each do |locale|
      I18n.with_locale(locale) do
        %i[player_required no_longer_idle].each do |code|
          assert_predicate Accounts::DeleteInactivePlayer.failure_message(code), :present?
        end
      end
    end
  end
end
