module Game
  module GameSetGaps
    def self.call(player_ids)
      return {} if player_ids.empty?

      rows = Goal.where(player_id: player_ids, custom_set_id: nil).pluck(:player_id, :position, :set_kind, :set_key)
      return {} if rows.empty?

      albums = Catalog::SetsByKey.call(season: Catalog::PublishedSeason.call, keys: rows.map { |_id, _position, kind, key| [ kind, key ] })
      held = HeldGames.among_players(player_ids.uniq, card_ids: albums.values.flat_map(&:card_ids).uniq)
      rows.each_with_object({}) do |(player_id, position, kind, key), gaps|
        album = albums[[ kind, key ]] or next
        owned = held.fetch(player_id, Set.new)
        album.card_ids.each { |card_id| ((gaps[player_id] ||= {})[card_id] ||= []) << position unless owned.include?(card_id) }
      end
    end
  end
end
