module Game
  # Published when the friend answers an open trade with a counter-proposal
  # (AD-8, AD-10): the counterer becomes the proposer. Identifiers only:
  # data = { trade_id:, proposer_id:, recipient_id: } as they stand after the
  # counter, on the new proposer's stream (Game::Operation.stream_name).
  class TradeCountered < RubyEventStore::Event
  end
end
