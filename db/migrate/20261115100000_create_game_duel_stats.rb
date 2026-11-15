class CreateGameDuelStats < ActiveRecord::Migration[8.1]
  STATS = %w[popularity rating release discovery circulation].freeze

  def change
    create_table :game_duel_stats do |t|
      t.references :card_season, null: false, index: { unique: true }, foreign_key: { to_table: :catalog_card_seasons }
      t.integer :popularity_value
      t.integer :rating_value, limit: 2
      t.date :release_value
      t.datetime :discovery_value
      t.integer :circulation_value
      STATS.each do |stat|
        t.decimal :"#{stat}_percentile", precision: 4, scale: 1
        t.float :"#{stat}_median_distance"
        t.decimal :"#{stat}_weekly_percentile", precision: 4, scale: 1
      end
      t.string :trump_stat, null: false
      t.string :trump_direction, null: false
      t.datetime :computed_at, null: false

      STATS.each do |stat|
        %w[percentile weekly_percentile].each do |column|
          t.check_constraint "#{stat}_#{column} BETWEEN 0 AND 100", name: "game_duel_stats_#{stat}_#{column}_check"
        end
        t.check_constraint "(#{stat}_value IS NULL) = (#{stat}_percentile IS NULL) AND (#{stat}_value IS NULL) = (#{stat}_median_distance IS NULL)",
          name: "game_duel_stats_#{stat}_together_check"
      end
      t.check_constraint STATS.map { "trump_stat = '#{it}'" }.join(" OR "), name: "game_duel_stats_trump_stat_check"
      t.check_constraint "trump_direction = 'high' OR trump_direction = 'low'", name: "game_duel_stats_trump_direction_check"
    end
  end
end
