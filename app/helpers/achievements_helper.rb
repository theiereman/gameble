module AchievementsHelper
  GLYPHS = {
    first_booster: "pack", boosters_10: "pack", boosters_100: "pack", boosters_500: "pack",
    first_epic: "gem", statistical_non_compliance: "outlier",
    first_legendary: "star",
    first_complete_set: "set", three_complete_sets: "set",
    first_trade: "trade",
    first_repost: "card",
    packaging_irregularity: "duplicate", excellence_in_mediocrity: "tokens", historical_asset_management: "hourglass",
    luck_is_a_marketing_concept: "clover", leave_request_denied: "refused",
    streamlined_opening_procedure: "skip", diligence_beyond_the_call_of_duty: "revealed",
    diversified_portfolio: "fan", market_concentration: "tower",
    first_claim_all_rights_reserved: "flag", a_discovery_of_ours: "lens", a_strictly_professional_relationship: "clasp",
    no_time_to_waste: "stopwatch", night_owl: "moon",
    hostile_takeover: "takeover", competitive_tender: "gavel", capital_gain: "growth", quarterly_targets_met: "ledger",
    insider_trading: "briefcase"
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
