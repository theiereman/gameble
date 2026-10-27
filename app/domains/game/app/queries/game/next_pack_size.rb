module Game
  # How many cards the next opening holds (EXPERIENCE.md, Implementation
  # notes, "Daily bonus booster"): the card count of the pack
  # Game::OpenPack would open at `now`, the oldest available of any kind
  # (the same scope and order as its `next_pack`), so a daily bonus pack
  # first in line says 3. Nil when none is available. Display data for the
  # booster screen and the opening exchange's answer.
  #
  #   Game::NextPackSize.call(player) # => 5 | 3 | nil
  module NextPackSize
    def self.call(player, now: Time.current)
      Pack.where(player_id: player.id).available(now).pick(Arel.sql("cardinality(card_season_ids)"))
    end
  end
end
