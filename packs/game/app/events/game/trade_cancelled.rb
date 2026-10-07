module Game
  # Published when the proposer cancels their open trade (AD-8, AD-10). Identifiers only:
  # data = { trade_id:, proposer_id:, recipient_id: }, on the proposer's
  # stream (Game::Operation.stream_name).
  class TradeCancelled < RubyEventStore::Event
  end
end
