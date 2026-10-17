# Builds sets of the fixture season straight into the catalog, with their
# members and the tiers they ask, for tests of what a player's tiers show.
module GameSets
  # A set holding `members` (card-season ids), asking `tiers` ({ tier => required }); its id.
  def insert_set(members, tiers, kind: "theme", key: "roguelike", params: { kind => key }, season: catalog_seasons(:one))
    set_id = Catalog::Set.insert_all!([ { season_id: season.id, kind:, key:, params: } ], returning: :id).rows.flatten.sole
    Catalog::SetMembership.insert_all!(members.each_with_index.map { |id, index| { set_id:, card_season_id: id, position: index + 1 } })
    Catalog::SetTier.insert_all!(tiers.map { |tier, required| { set_id:, tier: tier.to_s, required: } }) if tiers.any?
    set_id
  end

  # Four themes the fixture season's common card reaches at once, the
  # Metroidvania highest (gold); their ids, Metroidvania last.
  def insert_four_themes
    common = catalog_card_seasons(:common_card_one).id
    %w[roguelike horror cosy].map { insert_set([ common, catalog_card_seasons(:rare_card_one).id ], { bronze: 1, complete: 2 }, key: it) } +
      [ insert_set([ common ], { bronze: 1, silver: 1, gold: 1 }, key: "metroidvania") ]
  end
end
