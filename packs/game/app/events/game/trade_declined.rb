module Game
  # Published when the friend declines an open trade (AD-8, AD-10). Identifiers only:
  # data = { trade_id:, proposer_id:, recipient_id: }, on the proposer's
  # stream (Game::Operation.stream_name).
  class TradeDeclined < RubyEventStore::Event
  end
end
