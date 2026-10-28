require_relative "catalog_seeds"
require_relative "game_packs"
require_relative "holdings"

# Publishes a second season over the fixtures' five card-seasons, with one
# theme set of four tiers, and puts the players back before its allocation.
module SecondSeason
  include Holdings
  include GamePacks

  def publish_second_season(holder, held: fixture_tier_ids.first(3))
    season = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    rows = %i[common_card_one uncommon_card_one rare_card_one portal_one legendary_card_one].map do |name|
      one = catalog_card_seasons(name)
      { card_id: one.card_id, season_id: season.id, prestige_score: one.prestige_score, rating: one.rating, rarity: one.rarity, number: one.number }
    end
    cards = Catalog::CardSeason.insert_all!(rows, returning: :id).rows.flatten
    set = Catalog::Set.insert_all!([ { season_id: season.id, kind: "theme", key: "roguelike", params: { "theme" => "roguelike" } } ], returning: :id).rows.flatten.sole
    Catalog::SetMembership.insert_all!(cards.each_with_index.map { |id, index| { set_id: set, card_season_id: id, position: index + 1 } })
    Catalog::SetTier.insert_all!({ novice: 1, apprentice: 2, adept: 3, complete: 5 }.map { |tier, required| { set_id: set, tier: tier.to_s, required: } })
    held.each { hold(holder, it) }
    Game::PlayerState.where(player_id: holder.id).update_all(allocation_received_season: 1, allocation_seen_season: 1)
    [ season, set ]
  end
end
