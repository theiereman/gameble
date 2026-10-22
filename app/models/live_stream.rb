module LiveStream
  EVENTS = [ Game::PackOpened, Game::CardReposted, Game::TradeAccepted, Game::SetTierReached, Game::SetCompleted ].freeze

  TICKER_KINDS = %w[pull discovery trade set].freeze
  TICKER_SIZE = 12

  STRIP_SIZE = 3

  LANDING_SIZE = 5

  BATCHES = :live_stream_batches
  BATCH = AfterCommitBatch.new(BATCHES) { |notices| LiveFeedJob.perform_later(notices) }

  class << self
    def feed_streamables(locale = I18n.locale) = [ "live", locale.to_s ]

    def goal_streamables(locale = I18n.locale) = [ "goal", locale.to_s ]

    def call(event)
      BATCH.add(notices(event))
    end

    def notices(event)
      data = event.data
      case event
      when Game::PackOpened
        [ { pack_id: data[:pack_id] } ]
      when Game::CardReposted
        [ { player_id: data[:player_id], card_season_id: data[:card_season_id], at: event.metadata[:timestamp] } ]
      when Game::TradeAccepted
        [ { trade_id: data[:trade_id] } ]
      when Game::SetTierReached
        [ { player_id: data[:player_id], set_id: data[:set_id], tier: data[:tier] } ]
      when Game::SetCompleted
        [ { player_id: data[:player_id], set_id: data[:set_id], tier: "complete" } ]
      else
        []
      end
    end

    def ticker?(item)
      !item.filler && TICKER_KINDS.include?(item.entry.kind)
    end

    def ticker_items(locale: I18n.locale)
      FeedItems.call(Game::FeedEntries.call(nil, kind: TICKER_KINDS).first(TICKER_SIZE), locale:)
    end

    def landing_items(locale: I18n.locale)
      FeedItems.call(Game::FeedEntries.call(nil).first(LANDING_SIZE), locale:)
    end

    def strip_items(locale: I18n.locale)
      FeedItems.call(Game::FeedEntries.call(nil).first(STRIP_SIZE), locale:)
    end
  end
end
