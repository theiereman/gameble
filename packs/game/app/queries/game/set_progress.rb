module Game
  # How many members of each set a player holds the game of, in any edition:
  # a member counts when the player holds a copy of its game in any season
  # (Game::HeldGames' rule), once however many copies or editions. One
  # grouped query. Any player may be asked about, not only the one signed
  # in; nil (a visitor) owns nothing and costs no query. A set the player
  # holds nothing of is absent from the answer.
  #
  #   Game::SetProgress.call(player, [ set_id, … ]) # => { set_id => owned }
  module SetProgress
    def self.call(player, set_ids)
      return {} if player.nil? || set_ids.empty?

      Catalog::SetMembership.joins(:card_season)
        .where(set_id: set_ids, catalog_card_seasons: { card_id: HeldCards.relation(player) })
        .group(:set_id)
        .count
    end
  end
end
