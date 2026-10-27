require "test_helper"

class Accounts::ExportOfTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:administrator)
    @moderator = accounts_players(:moderator)
  end

  test "the profile is the player's own" do
    @player.update!(persona_name: "Léa", visibility: "friends_only", reduced_motion: true, last_seen_at: Time.utc(2026, 10, 1, 12))

    profile = Accounts::ExportOf.call(@player).profile

    assert_equal [ "76561197960287001", "Léa", "friends_only", true, @player.created_at, Time.utc(2026, 10, 1, 12) ],
      [ profile.steam_id, profile.persona_name, profile.visibility, profile.reduced_motion, profile.created_at, profile.last_seen_at ]
  end

  test "reports filed and received keep their reason and dates, never the other player" do
    assert Accounts::ReportPlayer.new.call(reporter: @player, reported: @other, reason: "cheating").success?
    assert Accounts::ReportPlayer.new.call(reporter: @other, reported: @player, reason: "harassment").success?

    export = Accounts::ExportOf.call(@player)

    assert_equal [ "cheating" ], export.reports_filed.map(&:reason)
    assert_equal [ :reason, :created_at ], export.reports_filed.first.to_h.keys
    assert_equal [ "harassment" ], export.reports_received.map(&:reason)
    assert_equal [ :reason, :created_at, :handled_at ], export.reports_received.first.to_h.keys
    assert_nil export.reports_received.first.handled_at
  end

  test "moderation decisions about the player keep their kind, date and reason, never the staff member" do
    assert Accounts::ReportPlayer.new.call(reporter: @other, reported: @player, reason: "inappropriate_name").success?
    assert Accounts::BanPlayer.new.call(staff: @moderator, player: @player, reason: "Offensive name").success?
    assert Accounts::UnbanPlayer.new.call(staff: @moderator, player: @player.reload).success?

    export = Accounts::ExportOf.call(@player.reload)

    assert_equal [ [ "ban", "Offensive name" ], [ "unban", nil ] ], export.decisions.map { [ it.kind, it.reason ] }
    assert_equal [ :kind, :created_at, :reason ], export.decisions.first.to_h.keys
    assert_not_nil export.reports_received.sole.handled_at
  end

  test "a player with nothing filed or decided has empty lists" do
    export = Accounts::ExportOf.call(@player)

    assert_empty export.reports_filed
    assert_empty export.reports_received
    assert_empty export.decisions
  end
end
