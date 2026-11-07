module Game
  module Handlers
    # Records the first reaction of each player to someone else's feed entry, once. Returns the entry's owners
    # when that player had never reacted to it before, and no one for a change of kind, a removal or a repeat.
    module ReactionNotices
      def self.call(event)
        reactor_id, feed_entry_id, kind = event.data.values_at(:player_id, :feed_entry_id, :kind)
        return [] unless kind

        owners = FeedEntry.where(id: feed_entry_id).pick(:player_id, :partner_id).to_a.compact
        return [] if owners.empty? || owners.include?(reactor_id)

        recorded = ReactionNotice.insert_all([ { feed_entry_id:, reactor_id: } ], unique_by: %i[feed_entry_id reactor_id], returning: :id)
        recorded.rows.any? ? owners : []
      end
    end
  end
end
