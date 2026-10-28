# A card-season only has a rarity once it is published, and a published one
# always has a number: giving rarities numbers the unnumbered ones first, in
# order after the highest number of their season, as publishing does.
module RatedCards
  def rate(card_season_ids, rarity)
    unnumbered = Catalog::CardSeason.where(id: card_season_ids, number: nil)
    unnumbered.order(:id).pluck(:id, :season_id).each do |id, season_id|
      Catalog::CardSeason.where(id:).update_all(number: Catalog::CardSeason.where(season_id:).maximum(:number).to_i + 1)
    end
    Catalog::CardSeason.where(id: card_season_ids).update_all(rarity:)
  end
end
