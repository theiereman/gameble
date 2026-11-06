module Game
  module NextPackSize
    def self.call(player, now: Time.current)
      Reserve::NAMES.to_h { [ it, Reserve.available(player.id, it, now:).pick(Arel.sql("cardinality(card_season_ids)")) ] }
    end
  end
end
