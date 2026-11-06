module Game
  module ActiveAvatar
    def self.call(player)
      for_players([ player ]).fetch(player.id)
    end

    def self.for_players(players)
      ids = players.map(&:id).uniq
      chosen = PlayerState.where(player_id: ids).where.not(active_avatar: nil).pluck(:player_id, :active_avatar)
        .to_h.transform_values { Avatars.find(it) }.compact
      administrators = administrators_among(chosen.select { |_, avatar| avatar.administrator_only }.keys)
      ids.index_with { |id| wearable(chosen[id], administrator: administrators.include?(id)) }
    end

    def self.administrators_among(ids)
      ids.empty? ? Set.new : Accounts::Player.administrator.where(id: ids).pluck(:id).to_set
    end

    def self.wearable(avatar, administrator:)
      return Avatars.default if avatar.nil? || (avatar.administrator_only && !administrator)

      avatar
    end
  end
end
