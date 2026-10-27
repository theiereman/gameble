module Game
  module NextPackSize
    def self.call(player, now: Time.current)
      Pack.where(player_id: player.id).available(now).pick(Arel.sql("cardinality(card_season_ids)"))
    end
  end
end
