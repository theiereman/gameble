require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/holdings"

# Game::ComputeDuelStats: every rated card-season of a published season gets one row of five stats, each ranked by midrank
# in its group toward its first direction, with its distance from the group's median, its trump and its last weekly
# percentiles; the whole table is replaced in one transaction that publishes one event.
class Game::ComputeDuelStatsTest < ActiveSupport::TestCase
  include CatalogSeeds
  include Holdings

  # A published season of rated card-seasons, numbered in card order (Commons unless `rarities` says otherwise); returns their ids.
  def published_card_seasons(count, rarities: nil, **seeds)
    season = seed_card_seasons(distinct_scores(count), **seeds)
    season.update!(status: :published, published_at: 1.day.ago)
    ids = Catalog::CardSeason.where(season_id: season.id).order(:id).ids
    ids.each_with_index do |id, index|
      Catalog::CardSeason.where(id:).update_all(rarity: rarities ? rarities.fetch(index) : 1, number: index + 1)
    end
    ids
  end

  def compute(reason = "weekly", now: Time.current)
    Game::ComputeDuelStats.new.call(reason:, now:)
  end

  def row(card_season_id) = Game::DuelStat.find_by!(card_season_id:)

  def column(ids, name) = ids.map { row(it)[name] }

  def discover(card_season_id, at)
    Game::FirstDiscovery.create!(card_season_id:, player_id: accounts_players(:player).id, discovered_at: at)
  end

  def duel_events = Rails.configuration.event_store.read.stream(Game::DuelStatsComputed::STREAM).to_a

  test "equal review counts share their midrank percentile" do
    ids = published_card_seasons(4, review_counts: [ 10, 20, 20, 40 ])

    assert compute.success?

    assert_equal [ 12.5, 50.0, 50.0, 87.5 ], column(ids, :popularity_percentile).map(&:to_f)
    assert_equal [ 10, 20, 20, 40 ], column(ids, :popularity_value)
  end

  test "a percentile is rounded half up to one decimal" do
    ids = published_card_seasons(3, review_counts: [ 10, 20, 40 ])

    compute

    assert_equal [ BigDecimal("16.7"), BigDecimal("50.0"), BigDecimal("83.3") ], column(ids, :popularity_percentile)
  end

  test "each value's distance from its group's median, in the stat's unit" do
    ids = published_card_seasons(3, review_counts: [ 10, 20, 40 ], ratings: [ 50.9, 60.0, 90.5 ],
      release_dates: [ Date.new(2000, 1, 1), Date.new(2000, 1, 11), Date.new(2000, 2, 1) ])

    compute

    assert_equal [ 10.0, 0.0, 20.0 ], column(ids, :popularity_median_distance)
    assert_equal [ 10.0, 0.0, 30.0 ], column(ids, :rating_median_distance)
    assert_equal [ 10.0, 0.0, 21.0 ], column(ids, :release_median_distance)
  end

  test "an equal whole percent is broken by the review count; the value is the whole percent" do
    ids = published_card_seasons(2, ratings: [ 91.4, 91.8 ], review_counts: [ 100, 50 ])

    compute

    assert_equal [ 91, 91 ], column(ids, :rating_value)
    assert_equal [ 75.0, 25.0 ], column(ids, :rating_percentile).map(&:to_f)
  end

  test "a later release ranks higher" do
    ids = published_card_seasons(2, release_dates: [ Date.new(2010, 1, 1), Date.new(2001, 1, 1) ])

    compute

    assert_equal [ 75.0, 25.0 ], column(ids, :release_percentile).map(&:to_f)
    assert_equal [ Date.new(2010, 1, 1), Date.new(2001, 1, 1) ], column(ids, :release_value)
  end

  test "an earlier discovery ranks higher; a card nobody pulled has no discovery or circulation" do
    first, second, unpulled = published_card_seasons(3)
    discover(first, Time.utc(2026, 11, 1, 12))
    discover(second, Time.utc(2026, 11, 2, 12))

    compute

    assert_equal [ 75.0, 25.0 ], column([ first, second ], :discovery_percentile).map(&:to_f)
    assert_equal [ 43_200.0, 43_200.0 ], column([ first, second ], :discovery_median_distance)
    unpulled = row(unpulled)
    assert_nil unpulled.discovery_value
    assert_nil unpulled.discovery_percentile
    assert_nil unpulled.discovery_median_distance
    assert_nil unpulled.circulation_value
    assert_nil unpulled.circulation_percentile
  end

  test "circulation counts distinct holders among the held editions of the same tier; Archives deposits and emptied holdings count nothing" do
    widespread, rare_common, epic, emptied = published_card_seasons(4, rarities: [ 1, 1, 4, 1 ])
    players = %i[player moderator administrator].map { accounts_players(it) }
    players.each { hold(it, widespread, 2) }
    hold(players.first, rare_common)
    hold(players.second, epic)
    hold(players.third, emptied, 0)
    Game::Market::ArchiveDeposit.create!(player_id: players.second.id, card_season_id: rare_common, quantity: 3)

    compute

    assert_equal [ 3, 1, 1, nil ], column([ widespread, rare_common, epic, emptied ], :circulation_value)
    assert_equal [ 75.0, 25.0, 50.0 ], column([ widespread, rare_common, epic ], :circulation_percentile).map(&:to_f)
    assert_nil row(emptied).circulation_percentile
  end

  test "a banned or deleted player holds nothing toward circulation" do
    held, = published_card_seasons(1)
    hold(accounts_players(:player), held)
    hold(accounts_players(:banned), held)
    deleted = accounts_players(:moderator)
    hold(deleted, held)
    deleted.update_columns(deleted_at: 1.day.ago, steam_id: nil)

    compute

    assert_equal 1, row(held).circulation_value
  end

  test "each season ranks its own editions, the same tier of two seasons apart" do
    first_season = published_card_seasons(2, review_counts: [ 10, 20 ])
    second_season = published_card_seasons(2, review_counts: [ 30, 40 ])
    hold(accounts_players(:player), first_season.first)
    hold(accounts_players(:player), second_season.first)
    hold(accounts_players(:moderator), second_season.first)

    compute

    assert_equal [ 25.0, 75.0, 25.0, 75.0 ], column(first_season + second_season, :popularity_percentile).map(&:to_f)
    assert_equal [ 50.0, 50.0 ], column([ first_season.first, second_season.first ], :circulation_percentile).map(&:to_f)
  end

  test "an unrated card-season, a draft season's and nobody's review count give no row or no popularity" do
    rated, unrated = published_card_seasons(2, review_counts: [ 10, nil ])
    Catalog::CardSeason.where(id: unrated).update_all(rarity: nil)
    reviewless, = published_card_seasons(1, review_counts: [ nil ])
    draft = seed_card_seasons([ 1.0 ])

    compute

    assert Game::DuelStat.exists?(card_season_id: rated)
    assert_not Game::DuelStat.exists?(card_season_id: unrated)
    assert_not Game::DuelStat.exists?(card_season_id: Catalog::CardSeason.where(season_id: draft.id).select(:id))
    assert_nil row(reviewless).popularity_value
    assert_nil row(reviewless).popularity_percentile
    assert_equal 50.0, row(reviewless).rating_percentile.to_f
  end

  test "the fixture season's editions each get a row, its first computation's percentiles as their last weekly ones" do
    now = Time.current.change(usec: 0)

    assert_equal 5, compute("first", now:).value!

    rows = Game::DuelStat.all.to_a
    assert_equal catalog_card_seasons(:portal_one, :common_card_one, :uncommon_card_one, :rare_card_one, :legendary_card_one).map(&:id).sort,
      rows.map(&:card_season_id).sort
    assert(rows.all? { it.computed_at == now })
    assert(rows.all? { it.rating_weekly_percentile == it.rating_percentile && it.discovery_weekly_percentile == it.discovery_percentile })
  end

  test "the trump is the stat farthest from 50, the earlier stat on a tie, high from 50 up" do
    stats = Game::DuelStat::STATS
    trump = ->(percentiles) { Game::DuelStatRows.trump(stats.zip(percentiles.map { it && BigDecimal(it.to_s) }).to_h) }

    assert_equal [ "rating", "high" ], trump.([ 60, 95, 10, 30, 50 ])
    assert_equal [ "release", "low" ], trump.([ 60, 70, 3, 30, 50 ])
    assert_equal [ "popularity", "high" ], trump.([ 90, 10, 50, 50, nil ])
    assert_equal [ "popularity", "high" ], trump.([ 50, 50, 50, 50, 50 ])
  end

  test "the stored trump follows the computed percentiles" do
    ids = published_card_seasons(4, review_counts: [ 10, 20, 30, 40 ])

    compute

    assert_equal [ [ "popularity", "low" ], [ "popularity", "high" ] ], [ ids.first, ids.last ].map { row(it).values_at(:trump_stat, :trump_direction) }
  end

  test "a weekly or first run keeps the previous percentiles as the last weekly ones; a season run keeps the last weekly ones" do
    ids = published_card_seasons(2, review_counts: [ 10, 40 ])
    compute

    { "season" => 30.0, "weekly" => 40.0, "first" => 40.0 }.each do |reason, weekly|
      Game::DuelStat.where(card_season_id: ids.last).update_all(popularity_percentile: 40.0, popularity_weekly_percentile: 30.0)

      compute(reason)

      assert_equal 75.0, row(ids.last).popularity_percentile.to_f, reason
      assert_equal weekly, row(ids.last).popularity_weekly_percentile.to_f, reason
    end
  end

  test "a weekly run carries a stat the previous row had no value for as no weekly percentile" do
    discovered, undiscovered = published_card_seasons(2)
    discover(discovered, Time.utc(2026, 11, 1, 12))
    compute
    assert_nil row(undiscovered).discovery_percentile
    discover(undiscovered, Time.utc(2026, 11, 2, 12))

    compute("weekly")

    assert_equal 25.0, row(undiscovered).discovery_percentile.to_f
    assert_nil row(undiscovered).discovery_weekly_percentile
    assert_equal 50.0, row(discovered).discovery_weekly_percentile.to_f
  end

  test "a card-season without a previous row takes its own percentiles as the last weekly ones, whatever the reason" do
    %w[season weekly].each do |reason|
      Game::DuelStat.delete_all
      ids = published_card_seasons(2, review_counts: [ 10, 40 ])

      compute(reason)

      assert_equal [ 25.0, 75.0 ], column(ids, :popularity_weekly_percentile).map(&:to_f), reason
    end
  end

  test "a run replaces every row and publishes one event with its reason" do
    compute("first", now: 1.week.ago)
    before = Game::DuelStat.ids

    assert compute("season").success?

    assert_equal 5, Game::DuelStat.count
    assert_empty before & Game::DuelStat.ids
    assert_equal 1, Game::DuelStat.distinct.count(:computed_at)
    assert_equal [ { reason: "first" }, { reason: "season" } ], duel_events.map(&:data)
  end

  test "an unknown reason fails, leaving the rows and the event stream as they were" do
    compute("first")
    before = Game::DuelStat.order(:id).pluck(:id, :computed_at)

    assert_equal :unknown_reason, compute("monthly").failure

    assert_equal before, Game::DuelStat.order(:id).pluck(:id, :computed_at)
    assert_equal 1, duel_events.size
  end
end
