# PostgreSQL stores `column IN (...)` on a varchar column in a form that db/schema.rb does not round-trip.
class WriteListChecksAsEqualities < ActiveRecord::Migration[8.1]
  LIST_CHECKS = [
    [ :accounts_moderation_actions, "accounts_moderation_actions_kind_check", "%s", :kind, %w[ban unban dismissal] ],
    [ :accounts_players, "accounts_players_visibility_check", "%s", :visibility, %w[public friends_only private] ],
    [ :accounts_reports, "accounts_reports_reason_check", "%s", :reason, %w[inappropriate_name cheating harassment other] ],
    [ :catalog_set_tiers, "catalog_set_tiers_tier_check", "%s", :tier, %w[bronze silver gold complete] ],
    [ :catalog_sets, "catalog_sets_kind_check", "%s", :kind,
      %w[publisher tome best_of_year theme franchise studio hall_of_fame ufo] ],
    [ :game_feed_entries, "game_feed_entries_pack_check", "(%s) = (pack_id IS NOT NULL AND position IS NOT NULL)",
      :kind, %w[pull discovery] ],
    [ :game_feed_entries, "game_feed_entries_kind_check", "%s", :kind, %w[pull discovery trade repost] ],
    [ :game_invitations, "game_invitations_status_check", "%s", :status, %w[pending accepted ignored] ],
    [ :game_trade_items, "game_trade_items_side_check", "%s", :side, %w[offer request] ],
    [ :game_trades, "game_trades_status_check", "%s", :status, %w[open cancelled declined accepted expired] ],
    [ :steam_apps, "steam_apps_details_exclusion_check", "details_exclusion IS NULL OR %s", :details_exclusion,
      %w[unavailable not_a_game no_title no_vertical_image no_release_date] ],
    [ :steam_apps, "steam_apps_review_exclusion_check", "review_exclusion IS NULL OR %s", :review_exclusion,
      %w[too_few_reviews unavailable malformed_reviews] ],
    [ :steam_import_runs, "steam_import_runs_status_check", "%s", :status,
      %w[pending running completed failed abandoned] ]
  ].freeze

  def change
    LIST_CHECKS.each do |table, name, shape, column, values|
      remove_check_constraint table, format(shape, in_list(column, values)), name: name
      add_check_constraint table, format(shape, equalities(column, values)), name: name, validate: false
    end
  end

  private

  def in_list(column, values)
    "#{column} IN (#{values.map { |value| "'#{value}'" }.join(", ")})"
  end

  def equalities(column, values)
    values.map { |value| "#{column} = '#{value}'" }.join(" OR ")
  end
end
