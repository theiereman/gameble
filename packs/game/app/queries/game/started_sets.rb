module Game
  # The sets a player has started (CAP-8): those of `sets` with at least one
  # member the player holds a copy of (AD-2: Game reads Catalog's
  # memberships). The narrowing is one subquery inside the relation, which
  # stays lazy: the caller pages it, with its count and its page as two
  # queries. Any player may be asked about; nil (a visitor) has started
  # nothing.
  #
  #   Game::StartedSets.relation(player, Catalog::Set relation) # => Catalog::Set relation
  module StartedSets
    def self.relation(player, sets)
      return sets.none if player.nil?

      memberships = Catalog::SetMembership.arel_table
      holdings = Holding.arel_table
      held = Catalog::SetMembership
        .joins(memberships.join(holdings).on(holdings[:card_season_id].eq(memberships[:card_season_id])).join_sources)
        .where(holdings[:player_id].eq(player.id))
        .where(holdings[:quantity].gt(0))
        .select(memberships[:set_id])
      sets.where(id: held)
    end
  end
end
