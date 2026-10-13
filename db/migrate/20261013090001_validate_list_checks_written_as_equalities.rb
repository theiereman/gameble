class ValidateListChecksWrittenAsEqualities < ActiveRecord::Migration[8.1]
  CHECKS = {
    accounts_moderation_actions: %w[accounts_moderation_actions_kind_check],
    accounts_players: %w[accounts_players_visibility_check],
    accounts_reports: %w[accounts_reports_reason_check],
    catalog_set_tiers: %w[catalog_set_tiers_tier_check],
    catalog_sets: %w[catalog_sets_kind_check],
    game_feed_entries: %w[game_feed_entries_pack_check game_feed_entries_kind_check],
    game_invitations: %w[game_invitations_status_check],
    game_trade_items: %w[game_trade_items_side_check],
    game_trades: %w[game_trades_status_check],
    steam_apps: %w[steam_apps_details_exclusion_check steam_apps_review_exclusion_check],
    steam_import_runs: %w[steam_import_runs_status_check]
  }.freeze

  def change
    CHECKS.each do |table, names|
      names.each { |name| validate_check_constraint table, name: name }
    end
  end
end
