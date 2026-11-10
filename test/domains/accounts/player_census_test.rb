require "test_helper"

class Accounts::PlayerCensusTest < ActiveSupport::TestCase
  setup do
    @now = Time.current
    Accounts::Player.update_all(created_at: @now - 30.days, last_seen_at: nil)
  end

  test "counts every remaining account, those opened in the last seven days and those seen in them" do
    Accounts::Player.create!(steam_id: "76561197960390001", created_at: @now - 2.days, last_seen_at: @now - 1.hour)
    Accounts::Player.create!(steam_id: "76561197960390002", created_at: @now - 8.days, last_seen_at: @now - 3.days)
    Accounts::Player.create!(steam_id: "76561197960390003", created_at: @now - 6.days)
    deleted = Accounts::Player.create!(steam_id: "76561197960390004", created_at: @now - 1.day, last_seen_at: @now)
    Accounts::DeletePlayer.new.call(player: deleted).value!

    figures = Accounts::PlayerCensus.call(now: @now)

    assert_equal Accounts::Player.where(deleted_at: nil).count, figures.total
    assert_equal 2, figures.joined_recently
    assert_equal 2, figures.active_recently
  end
end
