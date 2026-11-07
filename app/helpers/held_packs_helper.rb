module HeldPacksHelper
  def held_packs_json(held, player:, goals:)
    packs = held.values.compact
    return held if packs.empty?

    views = Catalog::CardViews.call(packs.flat_map(&:card_season_ids).uniq, locale: I18n.locale)
    shared = { player:, goals:, card_back: card_back_json(*Game::CardBacks.active_with_season(player)),
               tier_counts: tier_counts_json(Game::TierCounts.call(player)) }
    held.transform_values { |pack| pack && held_pack_json(pack, cards: pack.card_season_ids.map { views.fetch(it) }, **shared) }
  end

  def held_pack_after_json(pack, player:, now:)
    held = Game::HeldPacks.after(player, pack, now:)
    held && held_packs_json({ next: held }, player:, goals: GoalMarks.new(Game::GoalNeeds.call(player))).fetch(:next)
  end

  private
    def held_pack_json(pack, cards:, player:, goals:, card_back:, tier_counts:)
      { pack: pack_head_json(pack, card_back:), cards: pack_cards_json(cards, Game::FirstCopies.before_opening(player, pack), goals:),
        tierCountsBefore: tier_counts }
    end
end
