module DuelStream
  EVENTS = [ Game::DuelChallengeAccepted, Game::DuelChallengeLapsed, Game::DuelChallengeRefused,
    Game::DuelChallengeCancelled, Game::DuelRoundCalled, Game::DuelRoundAnswered, Game::DuelFinished ].freeze

  BATCHES = :duel_stream_batches
  BATCH = AfterCommitBatch.new(BATCHES) { |duel_ids| DuelStreamJob.perform_later(duel_ids.uniq) }

  class << self
    def streamables(stream_key, locale = I18n.locale) = [ "duel-seat", stream_key, locale.to_s ]

    def call(event)
      BATCH.add([ event.data[:duel_id] ])
    end
  end
end
