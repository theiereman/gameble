module Game
  # Published when a player sends a trade to a friend (AD-8, AD-10). Identifiers only:
  # data = { trade_id:, proposer_id:, recipient_id: }, on the proposer's
  # stream (Game::Operation.stream_name).
  class TradeProposed < RubyEventStore::Event
  end
end
