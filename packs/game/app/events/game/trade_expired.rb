module Game
  # Published when an open trade is closed 7 days after its last send or
  # counter (AD-8, AD-10). Identifiers only: data = { trade_id:, proposer_id:,
  # recipient_id: }, on the proposer's stream (Game::Operation.stream_name).
  class TradeExpired < RubyEventStore::Event
  end
end
