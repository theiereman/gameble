module LiveStream
  EVENTS = [ Game::PackOpened, Game::CardReposted ].freeze

  TICKER_KINDS = %w[pull discovery trade].freeze
  TICKER_SIZE = 12

  STRIP_SIZE = 3

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

    def strip_items(locale: I18n.locale)
      FeedItems.call(Game::FeedEntries.call(nil).first(STRIP_SIZE), locale:)
    end
  end
end
