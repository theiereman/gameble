module Game
  # The sets a player has started: those of `sets` with a member whose game
  # the player holds in any edition (Game::HeldGames' rule). The narrowing
  # is one subquery inside the relation, which stays lazy: the caller pages
  # it, with its count and its page as two queries. Any player may be asked
  # about; nil (a visitor) has started nothing.
  #
  #   Game::StartedSets.relation(player, Catalog::Set relation) # => Catalog::Set relation
  module StartedSets
    def self.relation(player, sets)
      return sets.none if player.nil?

      held = Catalog::SetMembership.joins(:card_season)
        .where(catalog_card_seasons: { card_id: HeldCards.relation(player) })
        .select(:set_id)
      sets.where(id: held)
    end
  end
end
