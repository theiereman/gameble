module Game
  # Published when an opening pulls a card nobody had pulled before in its
  # season, once per card-season (AD-9, AD-10, story 6.7), after the
  # opening's Game::PackOpened. Identifiers only: data = { player_id:,
  # card_season_id:, pack_id: }, on the player's stream
  # (Game::Operation.stream_name).
  class CardDiscovered < RubyEventStore::Event
  end
end
