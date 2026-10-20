module Game
  # The card-seasons a player chose for their profile showcase, in their
  # order, in one query; nil (a visitor) has none and costs no query.
  #
  #   Game::ChosenShowcase.call(player) # => [ card_season_id, … ]
  #   Game::ChosenShowcase.full?(ids)   # => whether no card can join them
  module ChosenShowcase
    SIZE = ShowcaseEntry::SIZE

    def self.call(player)
      return [] if player.nil?

      ShowcaseEntry.where(player_id: player.id).order(:position, :id).pluck(:card_season_id)
    end

    def self.full?(card_season_ids) = card_season_ids.size >= SIZE
  end
end
