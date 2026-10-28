require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/game_sets"
require_relative "../../support/game_trades"
require_relative "../../support/holdings"
require_relative "../../support/rake_tasks"
require_relative "../../support/second_season"

class Game::GrantCardBacksTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include GamePacks
  include GameSets
  include GameTrades
  include Holdings
  include RakeTasks
  include SecondSeason

  BACK_TIER_BY_SIZE = { 4 => "complete", 5 => "master", 9 => "master", 10 => "master", 19 => "master", 20 => "expert", 59 => "expert", 60 => "expert", 199 => "expert", 200 => "adept" }.freeze

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
    @common, @uncommon, @rare, @portal, @legendary = fixture_tier_ids
  end

  def unlocked(player = @player) = Game::CardBackUnlock.where(player_id: player.id).order(:id).pluck(:back)
  def unlock_events(player = @player) = game_events(player, Game::CardBackUnlocked)

  def reach(set_id, tier, player: @player, reached_by: "trade")
    Game::SetTier.create!(player_id: player.id, set_id:, tier:, reached_by:, reached_at: Time.current)
  end

  def reach_up_to(set_id, tiers, tier)
    tiers.keys.take_while { it != tier }.each { reach(set_id, it) }
  end

  def grant(player = @player, retroactive: false) = Game::GrantCardBacksJob.grant(player, retroactive:)

  def sized_theme(size, key: "roguelike", season: catalog_seasons(:one))
    tiers = Catalog::TierTable.tiers(size)
    [ insert_set([], tiers, kind: "theme", key:, params: { "theme" => key }, season:), tiers ]
  end

  BACK_TIER_BY_SIZE.each do |size, back_tier|
    test "a set of #{size} cards unlocks its back on #{back_tier}, not on the tier below" do
      set_id, tiers = sized_theme(size)
      reach_up_to(set_id, tiers, back_tier)
      grant

      assert_empty unlocked
      reach(set_id, back_tier)
      grant

      assert_equal [ "set-theme-roguelike" ], unlocked
    end
  end

  test "a gold of a season published before the tier table unlocks the back, silver does not" do
    set_id = insert_set([], { "bronze" => 1, "silver" => 2, "gold" => 3, "complete" => 5 }, kind: "theme", key: "cosy", params: { "theme" => "cosy" })
    reach(set_id, "bronze")
    reach(set_id, "silver")
    grant

    assert_empty unlocked
    reach(set_id, "gold")
    grant

    assert_equal [ "set-theme-cosy" ], unlocked
  end

  test "a hall of fame set unlocks its back" do
    set_id = insert_set([], Catalog::TierTable.tiers(30), kind: "hall_of_fame", key: "pepites", params: { "hall_of_fame" => "pepites" })
    Catalog::TierTable.tiers(30).each_key { reach(set_id, it) }
    grant

    assert_equal [ "set-hall_of_fame-pepites" ], unlocked
  end

  test "a franchise set grants nothing" do
    set_id = insert_set([], Catalog::TierTable.tiers(4), kind: "franchise", key: "roguelike", params: { "franchise" => "roguelike" })
    reach(set_id, "complete")

    assert_empty grant
    assert_empty unlocked
  end

  test "a theme without a back in the catalogue grants nothing" do
    set_id = insert_set([], Catalog::TierTable.tiers(4), kind: "theme", key: "unknown-theme", params: { "theme" => "unknown-theme" })
    reach(set_id, "complete")

    assert_empty grant
  end

  test "the same set in a later season does not unlock the back twice" do
    set_id, = sized_theme(4)
    reach(set_id, "complete")
    grant
    season = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    later_id, = sized_theme(4, season:)
    reach(later_id, "complete")
    grant

    assert_equal [ "set-theme-roguelike" ], unlocked
    assert_equal 1, unlock_events.size
  end

  test "a grant asked again writes and publishes once" do
    set_id, = sized_theme(4)
    reach(set_id, "complete")
    2.times { grant }

    assert_equal [ "set-theme-roguelike" ], unlocked
    assert_equal 1, unlock_events.size
    assert_equal [ { player_id: @player.id, back: "set-theme-roguelike" } ], unlock_events.map(&:data)
  end

  test "a trade that crosses the back tier unlocks the back for the recipient, with a toast event" do
    set_id = insert_set([ @common, @uncommon, @rare, @portal, @legendary ], Catalog::TierTable.tiers(5), kind: "theme", key: "roguelike", params: { "theme" => "roguelike" })
    hold(@other, @common, 2)
    hold(@other, @uncommon)

    perform_enqueued_jobs { conclude_trade(@player, @other, offer: { @rare => 1 }, request: { @common => 1 }) }

    assert_equal [ "master" ], Game::SetTier.where(player_id: @other.id, set_id:).pluck(:tier)
    assert_equal [ "set-theme-roguelike" ], unlocked(@other)
    assert_equal [ nil ], unlock_events(@other).map { it.data[:retroactive] }
    assert_empty unlocked
  end

  test "a tier received at the allocation unlocks its back silently" do
    season, = publish_second_season(@player, held: [ @common, @uncommon, @rare ])
    Catalog::Set.where(season_id: season.id).update_all(key: "cosy", params: { "theme" => "cosy" })

    perform_enqueued_jobs { Game::ReceiveSeasonAllocation.new.call(player: @player).value! }

    assert_equal [ "set-theme-cosy" ], unlocked
    assert_equal [ true ], unlock_events.map { it.data[:retroactive] }
  end

  test "a banned player is not granted" do
    set_id, = sized_theme(4)
    banned = accounts_players(:banned)
    reach(set_id, "complete", player: banned)

    Game::GrantCardBacksJob.perform_now(banned.id)

    assert_empty unlocked(banned)
  end

  test "the backfill unlocks silently, only for players in good standing, and once however often it runs" do
    set_id, = sized_theme(4)
    banned = accounts_players(:banned)
    [ @player, @other, banned ].each { reach(set_id, "complete", player: it) }

    2.times { Game::BackfillCardBacksJob.perform_now }

    assert_equal [ "set-theme-roguelike" ], unlocked
    assert_equal [ "set-theme-roguelike" ], unlocked(@other)
    assert_empty unlocked(banned)
    assert_equal [ true, true ], [ @player, @other ].flat_map { |player| unlock_events(player).map { it.data[:retroactive] } }
  end

  test "the rake task runs the backfill and says so" do
    set_id, = sized_theme(4)
    reach(set_id, "complete")

    output, = capture_io { 2.times { rake_task("game:backfill_card_backs").execute } }

    assert_equal [ "set-theme-roguelike" ], unlocked
    assert_match "game:backfill_card_backs", output
  end
end
