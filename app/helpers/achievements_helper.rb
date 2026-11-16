module AchievementsHelper
  GLYPHS = {
    first_booster: "pack", boosters_10: "pack", boosters_100: "pack", boosters_500: "pack",
    boosters_1000: "pack", boosters_5000: "pack", boosters_10000: "pack",
    first_epic: "gem", statistical_non_compliance: "outlier",
    first_legendary: "star",
    first_complete_set: "set", three_complete_sets: "set",
    first_trade: "trade", trades_10: "trade", trades_50: "trade", trades_100: "trade",
    first_repost: "card", reposts_10: "card", reposts_50: "card", reposts_200: "card",
    picoins_50k: "coin", picoins_500k: "coin", picoins_1m: "coin",
    friends_10: "friends", friends_25: "friends", friends_50: "friends",
    reactions_50: "thumb", reactions_200: "thumb", reactions_500: "thumb",
    self_assessment: "mirror", viral_memo: "megaphone",
    showcase_full: "showcase", everything_must_go: "broom",
    entrusted_100: "archive", entrusted_1000: "archive", entrusted_5000: "archive", entrusted_10000: "archive",
    employee_of_the_week: "crown", room_for_improvement: "anchor", sustained_growth: "sun", turnaround_plan: "rain",
    statement_of_requirements: "quill", delivered_on_schedule: "binder",
    packaging_irregularity: "duplicate", excellence_in_mediocrity: "tokens", historical_asset_management: "hourglass",
    luck_is_a_marketing_concept: "clover", leave_request_denied: "refused",
    streamlined_opening_procedure: "skip", diligence_beyond_the_call_of_duty: "revealed",
    diversified_portfolio: "fan", market_concentration: "tower",
    first_claim_all_rights_reserved: "flag", a_discovery_of_ours: "lens", a_strictly_professional_relationship: "clasp",
    no_time_to_waste: "stopwatch", night_owl: "moon",
    hostile_takeover: "takeover", competitive_tender: "gavel", capital_gain: "growth", quarterly_targets_met: "ledger",
    insider_trading: "briefcase",
    goals_10: "ledger", goals_25: "ledger", goals_50: "ledger",
    avatar_changed: "portrait", avatar_rebrand: "portrait", source_audit: "lens", funding_review: "coin",
    code_contribution: "clasp",
    profiles_viewed_1: "lens", profiles_viewed_5: "lens", profiles_viewed_20: "lens",
    profile_visits_10: "showcase", profile_visits_50: "showcase", profile_visits_100: "showcase"
  }.freeze

  def achievement_icon(tile)
    glyph = GLYPHS.fetch(tile.key)
    pixel_icon(tile.earned ? "achievement-#{glyph}" : "achievement-#{glyph}-locked", class: "achievement__glyph")
  end

  def achievement_back_reward(tile)
    back = Game::CardBacks.for_achievement(tile.key)
    return unless back

    image = image_tag(vite_asset_path("images/pixel/#{back.asset}-xs.png"), alt: "", width: 25, height: 38, class: "achievement__back-image")
    tag.p(safe_join([ image, t("achievements.back_reward", back: t("card_backs.names.#{back.key}")) ], " "), class: "achievement__back")
  end

  def achievement_avatar_reward(tile)
    avatar = Game::Avatars.for_achievement(tile.key)
    return unless avatar

    image = pixel_icon(avatar.icon, class: "achievement__avatar-image")
    tag.p(safe_join([ image, t("achievements.avatar_reward", avatar: t("avatars.names.#{avatar.key}")) ], " "), class: "achievement__avatar")
  end
end
