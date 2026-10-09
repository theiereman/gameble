module Game
  module NewFeedEntries
    def self.call(pack_ids: [], reposts: [])
      scopes = []
      scopes << FeedEntry.where(pack_id: pack_ids) if pack_ids.any?
      reposts.each do |repost|
        scopes << FeedEntry.where(kind: "repost", player_id: repost[:player_id], card_season_id: repost[:card_season_id],
          occurred_at: repost[:at])
      end
      return [] if scopes.empty?

      entries = scopes.reduce(:or).where(notable: true).newest_first.to_a
      players = Accounts::Player.where(id: entries.map(&:player_id).uniq).index_by(&:id)
      entries.filter_map do |entry|
        player = players[entry.player_id]
        FeedEntries::Entry.new(entry:, player:, filler: false) if Visibility.visible?(nil, player)
      end
    end
  end
end
