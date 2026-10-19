# Sets published from now on are tiered by rank; earlier seasons keep their metal tiers.
class WidenTierChecksToRanks < ActiveRecord::Migration[8.1]
  METALS = %w[bronze silver gold complete].freeze
  TIERS = %w[bronze silver gold novice apprentice adept expert master complete].freeze

  def change
    [ :catalog_set_tiers, :game_set_tiers ].each do |table|
      name = "#{table}_tier_check"
      remove_check_constraint table, equalities(METALS), name: name
      add_check_constraint table, equalities(TIERS), name: name, validate: false
    end
    remove_check_constraint :game_feed_entries, feed_tier_check(METALS), name: "game_feed_entries_tier_check"
    add_check_constraint :game_feed_entries, feed_tier_check(TIERS), name: "game_feed_entries_tier_check", validate: false
  end

  private

  def equalities(tiers)
    tiers.map { |tier| "tier = '#{tier}'" }.join(" OR ")
  end

  def feed_tier_check(tiers)
    "(tier IS NULL OR #{equalities(tiers)}) AND (set_count IS NULL OR set_count > 0)"
  end
end
