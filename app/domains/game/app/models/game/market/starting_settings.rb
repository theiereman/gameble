module Game
  module Market
    # The values of the first, closed version.
    module StartingSettings
      ATTRIBUTES = {
        entrustment_common: 10, entrustment_uncommon: 20, entrustment_rare: 50, entrustment_epic: 150, entrustment_legendary: 1_000,
        stamp_common: 1, stamp_uncommon: 10, stamp_rare: 20, stamp_epic: 50, stamp_legendary: 100,
        minimum_price_common: 13, minimum_price_uncommon: 34, minimum_price_rare: 78, minimum_price_epic: 223,
        minimum_price_legendary: 70_000,
        commission_basis_points: 1_000,
        daily_cap: 12_000,
        duration_short_hours: 12, duration_medium_hours: 24, duration_long_hours: 72, preselected_duration_hours: 24,
        increment_basis_points: 500,
        soft_close_seconds: 180,
        average_sale_count: 5, average_window_days: 90,
        feed_threshold_multiple: 10,
        unusual_maximum_multiple: 3,
        alert_destroyed_share_basis_points: 4_000,
        open: false
      }.freeze
    end
  end
end
