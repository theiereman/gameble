require "test_helper"

class Game::MarkBellReadTest < ActiveSupport::TestCase
  NOW = Time.utc(2026, 11, 16, 18, 0)

  setup do
    @hugo = accounts_players(:player)
    @max = accounts_players(:moderator)
  end

  def mark(keys, player = @hugo, now: NOW) = Game::MarkBellRead.new.call(player:, keys:, now:)

  def events = Rails.configuration.event_store.read.of_type([ Game::BellLinesRead ]).to_a

  test "the keys read are remembered for that player only" do
    assert mark([ "trade:abc:1", "mission:2026-11-16" ]).success?

    assert_equal Set.new([ "trade:abc:1", "mission:2026-11-16" ]), Game::BellReadKeys.call(@hugo)
    assert_empty Game::BellReadKeys.call(@max)
  end

  test "one event is published, with ids and no key" do
    mark([ "trade:abc:1", "invitation:def" ])

    assert_equal [ { player_id: @hugo.id, count: 2 } ], events.map(&:data)
  end

  test "reading a key twice keeps the later time and one row" do
    mark([ "trade:abc:1" ], now: NOW)
    assert mark([ "trade:abc:1", "trade:abc:1" ], now: NOW - 1.minute).success?

    assert_equal [ NOW ], Game::BellRead.where(player_id: @hugo.id).pluck(:read_at)
  end

  test "keys with a timestamp, as reaction and market lines carry, are accepted" do
    assert mark([ "reaction:9xYz:2026-11-16T17:59:00.123456Z", "trade-update:9xYz:2026-11-16T17:00:00.000000Z" ]).success?
  end

  test "no key, too many keys, or a malformed key is refused and nothing is written" do
    [ [], nil, "trade:abc:1", [ 7 ], [ "trade:abc:1", "<script>" ], [ "x" * 200 ],
      Array.new(Game::MarkBellRead::KEYS_PER_CALL + 1) { "mission:#{it}" } ].each do |keys|
      assert_equal :invalid_keys, mark(keys).failure, keys.inspect.first(40)
    end

    assert_equal 0, Game::BellRead.count
    assert_empty events
  end

  test "only the newest reads are kept per player" do
    kept = Game::BellRead::KEPT_PER_PLAYER
    (kept + 3).times.each_slice(50) do |slice|
      mark(slice.map { "mission:#{it}" }, now: NOW + slice.first.seconds)
    end
    mark([ "trade:abc:1" ], @max)

    assert_equal kept, Game::BellRead.where(player_id: @hugo.id).count
    assert_not Game::BellReadKeys.call(@hugo).include?("mission:0")
    assert_includes Game::BellReadKeys.call(@hugo), "mission:#{kept + 2}"
    assert_equal 1, Game::BellRead.where(player_id: @max.id).count
  end

  test "a visitor reads nothing" do
    assert_equal :player_required, mark([ "trade:abc:1" ], nil).failure
  end
end
