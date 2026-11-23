require "test_helper"

class Game::Market::WantedWriteGuardTest < ActiveSupport::TestCase
  ALLOWED = %w[
    app/domains/game/app/models/game/market/refresh_wanted.rb
    app/domains/game/app/models/game/market/wanted.rb
  ].freeze

  MODEL_WRITES = /\bWanted\b[^\n]*?\.\s*(?:create|insert|upsert|update|delete|destroy|new|find_or_create|find_or_initialize)\w*/
  RAW_WRITES = /(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM)\s+game_market_wanted\b/i

  test "no file but RefreshWanted writes a wanted row" do
    offenders = Dir[Rails.root.join("{app,lib}/**/*.{rb,rake,erb}")].filter_map do |path|
      relative = Pathname(path).relative_path_from(Rails.root).to_s
      next if ALLOWED.include?(relative)

      source = File.read(path)
      relative if [ MODEL_WRITES, RAW_WRITES ].any? { source.match?(it) }
    end

    assert_empty offenders
  end

  test "the guard sees a write when there is one" do
    assert_match MODEL_WRITES, "Game::Market::Wanted.insert_all(rows)"
    assert_match MODEL_WRITES, "Wanted.where(player_id: 1).delete_all"
    assert_match RAW_WRITES, "DELETE FROM game_market_wanted WHERE player_id = 1"
  end
end
