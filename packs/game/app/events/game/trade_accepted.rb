module Game
  # Published when the friend accepts an open trade and both sides are swapped
  # (AD-8, AD-10). Identifiers only: data = { trade_id:, proposer_id:,
  # recipient_id: }, on the proposer's stream (Game::Operation.stream_name).
  class TradeAccepted < RubyEventStore::Event
  end
end
