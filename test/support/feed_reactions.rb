# A feed entry written straight, for the tests of the reactions on it.
module FeedReactions
  def feed_entry_of(player, at: Time.current)
    Game::FeedEntry.record_repost(player_id: player.id, card_season_id: catalog_card_seasons(:portal_one).id, at:)
  end

  def react(player, entry, kind)
    Game::ReactToFeedEntry.new.call(player:, entry_token: entry.token, kind:)
  end

  def reaction_counts(entry, viewer: nil)
    Game::FeedReactionSummaries.call([ entry.id ], viewer:).fetch(entry.id)
  end
end
