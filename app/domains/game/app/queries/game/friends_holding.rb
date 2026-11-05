module Game
  module FriendsHolding
    Holder = Data.define(:friend, :edition, :copies, :asked) do
      def player = friend.player
      def card_season_id = edition.card_season_id
    end

    def self.call(player, card_id:, card_season_id:, now: Time.current)
      return [] unless Visibility.open_to_friends?(player)

      friends = FriendsPresence.call(player, now:).reject { it.state == :private }
      return [] if friends.empty?

      ids = friends.map { it.player.id }
      editions = TradeSuggestions::FreeEditions.call(ids, [ card_id ])
      asked = asked_friend_ids(player, ids, card_id, now)
      holders = friends.filter_map do |friend|
        held = TradeSuggestions::FreeEditions.spare(editions.fetch([ friend.player.id, card_id ], []))
        next if held.empty?

        edition = held.find { it.card_season_id == card_season_id } || TradeSuggestions::FreeEditions.placed(held)
        Holder.new(friend:, edition:, copies: held.sum(&:free), asked: asked.include?(friend.player.id))
      end
      holders.sort_by { [ holder_asked(it), -it.copies, it.player.token ] }
    end

    def self.asked_friend_ids(player, friend_ids, card_id, now)
      requesting = TradeItem.where(side: "request", card_season_id: Catalog::CardSeason.where(card_id:).select(:id)).select(:trade_id)
      Trade.in_progress.where(proposer_id: player.id, recipient_id: friend_ids).where(Trade.arel_table[:expires_at].gt(now))
        .where(id: requesting).where.not(id: TradeItem.where(side: "offer").select(:trade_id)).pluck(:recipient_id).to_set
    end

    def self.holder_asked(holder) = holder.asked ? 1 : 0

    private_class_method :holder_asked, :asked_friend_ids
  end
end
