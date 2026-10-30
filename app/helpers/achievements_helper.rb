module AchievementsHelper
  GLYPHS = {
    first_booster: "pack", boosters_10: "pack", boosters_100: "pack", boosters_500: "pack",
    first_epic: "gem",
    first_legendary: "star",
    first_complete_set: "set", three_complete_sets: "set",
    first_trade: "trade",
    first_repost: "card"
  }.freeze

  def achievement_icon(tile)
    glyph = GLYPHS.fetch(tile.key)
    pixel_icon(tile.earned || tile.ready ? "achievement-#{glyph}" : "achievement-#{glyph}-locked", class: "achievement__glyph")
  end

  def achievement_back_reward(tile)
    back = Game::CardBacks.for_achievement(tile.key)
    return unless back

    image = image_tag(vite_asset_path("images/pixel/#{back.asset}-xs.png"), alt: "", width: 25, height: 38, class: "achievement__back-image")
    tag.p(safe_join([ image, t("achievements.back_reward", back: t("card_backs.names.#{back.key}")) ], " "), class: "achievement__back")
  end
end
