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
    pixel_icon(tile.earned ? "achievement-#{glyph}" : "achievement-#{glyph}-locked", class: "achievement__glyph")
  end
end
