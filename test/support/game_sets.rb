require_relative "catalog_seeds"

# Builds sets of the fixture season straight into the catalog, with their
# members and the tiers they ask, for tests of what a player's tiers show.
module GameSets
  include CatalogSeeds

  # A set holding `members` (card-season ids), asking `tiers` ({ tier => required }); its id.
  def insert_set(members, tiers, kind: "theme", key: "roguelike", params: { kind => key }, season: catalog_seasons(:one))
    set_id = Catalog::Set.insert_all!([ { season_id: season.id, kind:, key:, params: } ], returning: :id).rows.flatten.sole
    Catalog::SetMembership.insert_all!(members.each_with_index.map { |id, index| { set_id:, card_season_id: id, position: index + 1 } }) if members.any?
    Catalog::SetTier.insert_all!(tiers.map { |tier, required| { set_id:, tier: tier.to_s, required: } }) if tiers.any?
    set_id
  end

  # Four themes of five cards the fixture season's common card reaches at
  # once, the Metroidvania highest (gold); their ids, Metroidvania last.
  def insert_four_themes
    members = [ catalog_card_seasons(:common_card_one).id, catalog_card_seasons(:rare_card_one).id, *unheld_cards(3) ]
    %w[roguelike horror cosy].map { insert_set(members, { bronze: 1, complete: 5 }, key: it) } +
      [ insert_set(members, { bronze: 1, silver: 1, gold: 1, complete: 5 }, key: "metroidvania") ]
  end

  # `count` new cards of the fixture season no player holds, to bring a set
  # up to a size with tiers; their card-season ids.
  def unheld_cards(count)
    prefix = "unheld-#{SecureRandom.hex(4)}"
    season = seed_card_seasons(Array.new(count) { 0.1 + (it * 0.001) }, season: catalog_seasons(:one), prefix:)
    cards = Catalog::CardSeason.where(season_id: season.id, card_id: Catalog::Card.where("slug LIKE ?", "#{prefix}-%").select(:id))
    cards.update_all(rarity: Catalog::Rarity::TIERS.keys.first)
    cards.order(:id).ids
  end

  # A new published season (the next number) of `count` common cards,
  # reviewed `review_counts` times in card order (nil: unreviewed), seeded
  # with CatalogSeeds; the season and its card-season ids in card order.
  def published_cards(count, review_counts: Array.new(count))
    season = seed_card_seasons(Array.new(count) { |index| (count - index).to_f }, review_counts:, prefix: "board")
    Catalog::CardSeason.where(season_id: season.id).update_all(rarity: Catalog::Rarity::TIERS.keys.first)
    season.update!(status: :published, published_at: Time.current)
    [ season, Catalog::CardSeason.where(season_id: season.id).order(:id).ids ]
  end

  # A theme of `season` holding `members`, tiered as an earlier season
  # tiered a theme of their number (bronze, silver and gold at 10, 25 and
  # 50 % rounded up); its id.
  def insert_theme(members, key:, season:)
    insert_set(members, metal_tiers(members.size), kind: "theme", key:, params: { "theme" => key }, season:)
  end

  # A theme of `season` holding `members`, tiered as publication tiers a set
  # of their number now (Catalog::TierTable); its id.
  def insert_ranked_theme(members, key:, season:)
    insert_set(members, Catalog::TierTable.tiers(members.size), kind: "theme", key:, params: { "theme" => key }, season:)
  end

  def metal_tiers(count)
    { "bronze" => 10, "silver" => 25, "gold" => 50 }.transform_values { |percent| (count * percent).ceildiv(100) }.merge("complete" => count)
  end

  # Copies of each card-season of `ids` for `player`, last gained at `gained_at`.
  def hold_all(player, ids, gained_at: nil, quantity: 1)
    now = Time.current
    Game::Holding.insert_all!(ids.map { |card_season_id| { player_id: player.id, card_season_id:, quantity:, last_gained_at: gained_at, created_at: now, updated_at: now } })
  end
end
