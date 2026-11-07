module Game
  # A player's one reaction to a feed entry: set, changed (kind) or removed (kind nil).
  class ReactToFeedEntry < Operation
    def call(player:, entry_token:, kind:)
      player = step require_player(player)
      kind = step known_kind(kind)

      transaction do
        entry = step visible_entry(player, entry_token)
        step write(player, entry, kind)
        step publish(FeedEntryReacted.new(data: { player_id: player.id, feed_entry_id: entry.id, kind: }), stream_name: stream_name(player.id))
        entry
      end
    end

    private

    def known_kind(kind)
      kind.nil? || FeedReaction::KINDS.include?(kind) ? Success(kind) : Failure(:unknown_reaction)
    end

    def visible_entry(player, token)
      entry = VisibleFeedEntry.call(player, token)
      entry ? Success(entry) : Failure(:entry_not_found)
    end

    def write(player, entry, kind)
      if kind
        FeedReaction.upsert({ player_id: player.id, feed_entry_id: entry.id, kind: }, unique_by: %i[player_id feed_entry_id])
      else
        FeedReaction.where(player_id: player.id, feed_entry_id: entry.id).delete_all
      end
      Success()
    end
  end
end
