module Game
  # How many distinct cards of each set a player owns (CAP-6): one grouped
  # query joining Catalog's set memberships (AD-2: Game reads Catalog) to the
  # player's holdings with copies left. A card in several sets counts in
  # each; its copies count once (one holding row per card-season, AD-6). Any
  # player may be asked about, not only the one signed in; nil (a visitor)
  # owns nothing and costs no query. A set the player owns nothing of is
  # absent from the answer.
  #
  #   Game::SetProgress.call(player, [ set_id, … ]) # => { set_id => owned }
  module SetProgress
    def self.call(player, set_ids)
      return {} if player.nil? || set_ids.empty?

      memberships = Catalog::SetMembership.arel_table
      holdings = Holding.arel_table
      Holding.where(player_id: player.id).where(holdings[:quantity].gt(0))
        .joins(holdings.join(memberships).on(memberships[:card_season_id].eq(holdings[:card_season_id])).join_sources)
        .where(memberships[:set_id].in(set_ids))
        .group(memberships[:set_id])
        .count
    end
  end
end
