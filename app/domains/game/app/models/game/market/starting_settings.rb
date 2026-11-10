module Game
  module Market
    # The values of the first, closed version.
    module StartingSettings
      ATTRIBUTES = {
        entrustment_common: 1_000, entrustment_uncommon: 2_000, entrustment_rare: 5_000, entrustment_epic: 15_000, entrustment_legendary: 100_000,
        stamp_common: 100, stamp_uncommon: 1_000, stamp_rare: 2_000, stamp_epic: 5_000, stamp_legendary: 10_000,
        minimum_price_common: 1_300, minimum_price_uncommon: 3_400, minimum_price_rare: 7_800, minimum_price_epic: 22_300,
        minimum_price_legendary: 7_000_000,
        commission_basis_points: 1_000,
        daily_cap: 1_200_000,
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
