require "test_helper"

class Accounts::NoteExportTest < ActiveSupport::TestCase
  setup { @player = accounts_players(:player) }

  def note(player = @player, at: Time.utc(2026, 10, 14, 9, 30)) = Accounts::NoteExport.new.call(player:, at:)

  test "the time of the player's last export is kept" do
    assert note.success?
    assert_equal Time.utc(2026, 10, 14, 9, 30), @player.reload.last_exported_at

    note(at: Time.utc(2026, 10, 15, 8))
    assert_equal Time.utc(2026, 10, 15, 8), @player.reload.last_exported_at
  end

  test "a banned or deleted player, or no player, is refused" do
    assert_equal Dry::Monads::Failure(:player_required), note(accounts_players(:banned))
    assert_equal Dry::Monads::Failure(:player_required), note(nil)
    Accounts::DeletePlayer.new.call(player: @player).value!
    assert_equal Dry::Monads::Failure(:player_required), note
    assert_nil @player.reload.last_exported_at
  end
end
