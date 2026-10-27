module Game
  module NewFeedEntries
    def self.call(pack_ids: [], reposts: [], trade_ids: [], sets: [])
      scopes = []
      scopes << FeedEntry.where(pack_id: pack_ids) if pack_ids.any?
      scopes << FeedEntry.where(trade_id: trade_ids) if trade_ids.any?
      reposts.each do |repost|
        scopes << FeedEntry.where(kind: "repost", player_id: repost[:player_id], card_season_id: repost[:card_season_id],
          occurred_at: repost[:at])
      end
      sets.each do |reached|
        reached_at = SetTier.where(player_id: reached[:player_id], set_id: reached[:set_id], tier: reached[:tier]).select(:reached_at)
        scopes << FeedEntry.where(kind: "set", player_id: reached[:player_id], occurred_at: reached_at)
      end
      return [] if scopes.empty?

      entries = scopes.reduce(:or).where(notable: true).newest_first.to_a
      players = Accounts::Player.where(id: entries.flat_map { [ it.player_id, it.partner_id ] }.compact.uniq).index_by(&:id)
      entries.filter_map do |entry|
        player = players[entry.player_id]
        partner = players[entry.partner_id]
        next unless Visibility.visible?(nil, player)
        next if entry.partner_id && !Visibility.visible?(nil, partner)

        FeedEntries::Entry.new(entry:, player:, partner:, filler: false)
      end
    end
  end
end
