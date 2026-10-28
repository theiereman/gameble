require "test_helper"

class Accounts::EraseBannedPlayerTest < ActiveSupport::TestCase
  setup do
    @administrator = accounts_players(:administrator)
    @banned = accounts_players(:banned)
  end

  def erase(player = @banned, staff: @administrator) = Accounts::EraseBannedPlayer.new.call(staff:, player:)

  def deleted_events = Rails.configuration.event_store.read.of_type(Accounts::PlayerDeleted).to_a

  test "an administrator erases a banned player: the account is anonymised, the ban stays, the history records the erasure" do
    @banned.update!(persona_name: "Exile")

    assert_equal @banned, erase.value!

    @banned.reload
    assert_predicate @banned, :deleted?
    assert_predicate @banned, :banned?
    assert_nil @banned.steam_id
    assert_nil @banned.persona_name
    action = Accounts::ModerationAction.where(player: @banned).order(:id).last
    assert_equal [ "erasure", @administrator.id ], [ action.kind, action.staff_id ]
    assert_nil action.reason
  end

  test "one event is published, the deletion of the account" do
    assert_difference -> { deleted_events.size }, 1 do
      erase
    end

    assert_equal [ { player_id: @banned.id } ], deleted_events.map(&:data)
  end

  test "a moderator does not erase: only an administrator does" do
    assert_equal Dry::Monads::Failure(:administrator_required), erase(staff: accounts_players(:moderator))
    assert_equal Dry::Monads::Failure(:administrator_required), erase(staff: @banned)
    assert_equal Dry::Monads::Failure(:administrator_required), erase(staff: nil)
    assert_not_predicate @banned.reload, :deleted?
    assert_empty deleted_events
  end

  test "a player in good standing, a deleted one and an unsaved one are refused" do
    assert_equal Dry::Monads::Failure(:not_banned), erase(accounts_players(:player))
    assert_equal Dry::Monads::Failure(:player_not_found), erase(Accounts::Player.new)
    erase.value!
    assert_equal Dry::Monads::Failure(:player_not_found), erase
    assert_equal 1, deleted_events.size
  end

  test "an administrator does not erase an administrator, banned or not" do
    other = Accounts::Player.create!(steam_id: "76561197960361111", role: :administrator, banned_at: 1.day.ago)

    assert_equal Dry::Monads::Failure(:outranked), erase(other)
    assert_not_predicate other.reload, :deleted?
  end

  test "a failed deletion rolls back the history row" do
    failing = Object.new.tap { |operation| operation.define_singleton_method(:call) { |**| Dry::Monads::Failure(:player_required) } }
    Accounts::DeletePlayer.define_singleton_method(:new) { failing }
    begin
      assert_no_difference -> { Accounts::ModerationAction.count } do
        assert_equal Dry::Monads::Failure(:player_required), erase
      end
    ensure
      Accounts::DeletePlayer.singleton_class.remove_method(:new)
    end
  end

  test "the deletion alone still refuses a banned player" do
    assert_equal Dry::Monads::Failure(:player_required), Accounts::DeletePlayer.new.call(player: @banned)
    assert_not_predicate @banned.reload, :deleted?
  end

  test "the history kind constraint accepts the erasure and refuses an unknown kind" do
    Accounts::ModerationAction.create!(kind: :erasure, player: @banned, staff: @administrator)

    assert_raises(ActiveRecord::StatementInvalid) do
      Accounts::ModerationAction.insert!({ kind: "unknown", player_id: @banned.id, staff_id: @administrator.id, created_at: Time.current })
    end
  end
end
