module Game
  module ActiveAvatar
    def self.call(player)
      for_players([ player ]).fetch(player.id)
    end

    def self.for_players(players)
      ids = players.map(&:id).uniq
      chosen = PlayerState.where(player_id: ids).where.not(active_avatar: nil).pluck(:player_id, :active_avatar).to_h
      ids.index_with { Avatars.find(chosen[it]) || Avatars.default }
    end
  end
end
