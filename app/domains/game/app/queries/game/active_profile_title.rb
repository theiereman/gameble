module Game
  module ActiveProfileTitle
    def self.call(player, titles: ProfileTitles.call(player))
      kind, key, rank = PlayerState.where(player_id: player.id).pick(:active_title_kind, :active_title_key, :active_title_rank)
      titles.find { it.kind == kind && it.key == key && it.rank == rank } if kind
    end
  end
end
