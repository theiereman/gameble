require "test_helper"
require_relative "../../support/catalog_seeds"
require Rails.root.join("db/migrate/20261015130000_delete_retired_set_kinds").to_s
require Rails.root.join("db/migrate/20261015130001_narrow_catalog_sets_kind_check").to_s

# The tomes, publisher sets and best-of-year sets go, in every season, with
# their memberships, tiers and completions; the kind check then refuses them.
class Catalog::DeleteRetiredSetKindsMigrationTest < ActiveSupport::TestCase
  include CatalogSeeds

  RETIRED_KINDS = %w[tome publisher best_of_year].freeze

  def run_migration(migration, direction = :up)
    ActiveRecord::Migration.suppress_messages { migration.new.migrate(direction) }
  end

  # strong_migrations refuses a validation inside the test's transaction, so the check is validated directly.
  def migrate
    run_migration(DeleteRetiredSetKinds)
    run_migration(NarrowCatalogSetsKindCheck)
    ActiveRecord::Base.connection.execute("ALTER TABLE catalog_sets VALIDATE CONSTRAINT catalog_sets_kind_check")
  end

  # The kind check as it stood before the retired kinds were removed.
  def widen_kind_check
    run_migration(NarrowCatalogSetsKindCheck, :down)
  end

  def insert_set(season_id, kind, key, params, card_season_ids)
    set_id = Catalog::Set.insert_all!([ { season_id:, kind:, key:, params: } ], returning: :id).rows.flatten.sole
    Catalog::SetMembership.insert_all!(card_season_ids.each_with_index.map { |card_season_id, index| { set_id:, card_season_id:, position: index + 1 } })
    Catalog::SetTier.insert_all!([ { set_id:, tier: "complete", required: card_season_ids.size } ])
    insert_completion(set_id)
    set_id
  end

  def insert_completion(set_id)
    ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql_array([
      "INSERT INTO game_set_completions (player_id, set_id, completed_at, created_at, updated_at) VALUES (?, ?, NOW(), NOW(), NOW())",
      accounts_players(:player).id, set_id
    ]))
  end

  def completed_set_ids
    ActiveRecord::Base.connection.select_values("SELECT set_id FROM game_set_completions").map(&:to_i)
  end

  def retired_season
    season_id = catalog_seasons(:one).id
    ids = %i[portal_one common_card_one uncommon_card_one].map { catalog_card_seasons(it).id }
    [
      insert_set(season_id, "tome", "action-1", { "genre" => "action", "volume" => 1, "volumes" => 1 }, ids),
      insert_set(season_id, "publisher", "valve", { "publisher" => "Valve" }, ids.first(1)),
      insert_set(season_id, "best_of_year", "2007", { "year" => 2007 }, ids.last(2))
    ]
  end

  def themed_season
    season = seed_published_sets([])
    card_season_id = Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(:portal).id, season_id: season.id, prestige_score: 0.9,
      rating: 95, rarity: 5, number: 1, main_theme: "puzzle" } ], returning: :id).rows.flatten.sole
    [
      insert_set(season.id, "theme", "puzzle", { "theme" => "puzzle" }, [ card_season_id ]),
      insert_set(season.id, "hall_of_fame", "pepites", { "hall_of_fame" => "pepites" }, [ card_season_id ])
    ]
  end

  # A holding, a feed entry and an achievement unlock on a card-season of the retired sets.
  def game_rows
    player_id = accounts_players(:player).id
    card_season_id = catalog_card_seasons(:portal_one).id
    Game::Holding.create!(player_id:, card_season_id:, quantity: 2)
    Game::FeedEntry.record_repost(player_id:, card_season_id:, at: Time.current)
    Game::AchievementUnlock.record(player_id, :first_booster, Time.current)
  end

  def untouched_counts
    [ Catalog::CardSeason, Game::Holding, Game::FeedEntry, Game::AchievementUnlock ].map(&:count)
  end

  test "the retired sets go with their memberships, tiers and completions; every other row stays" do
    widen_kind_check
    retired = retired_season
    themed = themed_season
    kept = [ catalog_sets(:valve_one).id, *themed ]
    kept_memberships = Catalog::SetMembership.where(set_id: kept).count
    game_rows
    counts = untouched_counts
    assert counts.all?(&:positive?)

    migrate

    assert_empty Catalog::Set.where(kind: RETIRED_KINDS)
    assert_empty Catalog::SetMembership.where(set_id: retired)
    assert_empty Catalog::SetTier.where(set_id: retired)
    assert_empty completed_set_ids & retired
    assert_equal kept.sort, Catalog::Set.ids.sort
    assert_equal kept_memberships, Catalog::SetMembership.where(set_id: kept).count
    assert_equal kept.sort, Catalog::SetTier.distinct.pluck(:set_id).sort
    assert_equal themed.sort, completed_set_ids.sort
    assert_equal counts, untouched_counts
  end

  test "a database with no retired set loses nothing, and its kind check then refuses a tome" do
    widen_kind_check
    themed_season
    rows = -> { [ Catalog::Set, Catalog::SetMembership, Catalog::SetTier ].map(&:count) + [ completed_set_ids.size ] }
    before = rows.call

    migrate

    assert_equal before, rows.call
    assert_raises(ActiveRecord::CheckViolation) do
      Catalog::Set.insert_all!([ { season_id: catalog_seasons(:one).id, kind: "tome", key: "action-1" } ])
    end
  end

  test "the delete cannot be undone" do
    assert_raises(ActiveRecord::IrreversibleMigration) { run_migration(DeleteRetiredSetKinds, :down) }
  end
end
