module Game
  module ActiveProfileTitle
    def self.call(player, titles: ProfileTitles.call(player))
      kind, key, rank = PlayerState.where(player_id: player.id).pick(:active_title_kind, :active_title_key, :active_title_rank)
      titles.find { it.kind == kind && it.key == key && it.rank == rank } if kind
    end

    def self.for_players(players)
      chosen = PlayerState.where(player_id: players.map(&:id)).where.not(active_title_kind: nil)
        .pluck(:player_id, :active_title_kind, :active_title_key, :active_title_rank)
      return {} if chosen.empty?

      earned = ProfileTitles.for_players(players.select { |player| chosen.any? { it.first == player.id } })
      chosen.each_with_object({}) do |(player_id, kind, key, rank), found|
        title = earned.fetch(player_id, []).find { it.kind == kind && it.key == key && it.rank == rank }
        found[player_id] = title if title
      end
    end
  end
end
