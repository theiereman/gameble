require "test_helper"

class Accounts::RecordExportTest < ActiveSupport::TestCase
  setup { @player = accounts_players(:player) }

  def note(player = @player, at: Time.utc(2026, 10, 14, 9, 30), file: "{}") = Accounts::RecordExport.new.call(player:, at:, file:)

  def kept_file = Accounts::LastExportOf.call(@player.reload)&.file

  test "the last export's time and file are kept, the next one replacing them" do
    assert_nil Accounts::LastExportOf.call(@player)
    assert note(file: '{"first":true}').success?
    assert_equal Time.utc(2026, 10, 14, 9, 30), @player.reload.last_exported_at
    assert_equal '{"first":true}', kept_file

    note(at: Time.utc(2026, 10, 15, 8), file: '{"second":true}')
    last = Accounts::LastExportOf.call(@player.reload)
    assert_equal [ '{"second":true}', Time.utc(2026, 10, 15, 8) ], [ last.file, last.exported_at ]
    assert_equal 1, Accounts::DataExport.where(player_id: @player.id).count
  end

  test "a second export within five minutes of the last is refused, and allowed after" do
    note
    assert_equal Time.utc(2026, 10, 14, 9, 35), @player.next_export_at(Time.utc(2026, 10, 14, 9, 31))

    assert_equal Dry::Monads::Failure(:export_too_soon), note(at: Time.utc(2026, 10, 14, 9, 34, 59), file: '{"late":true}')
    assert_equal "{}", kept_file
    assert_equal Time.utc(2026, 10, 14, 9, 30), @player.reload.last_exported_at

    assert note(at: Time.utc(2026, 10, 14, 9, 35)).success?
    assert_nil @player.reload.next_export_at(Time.utc(2026, 10, 14, 9, 40))
  end

  test "a banned or deleted player, or no player, is refused" do
    assert_equal Dry::Monads::Failure(:player_required), note(accounts_players(:banned))
    assert_equal Dry::Monads::Failure(:player_required), note(nil)
    Accounts::DeletePlayer.new.call(player: @player).value!
    assert_equal Dry::Monads::Failure(:player_required), note
    assert_nil @player.reload.last_exported_at
  end
end
