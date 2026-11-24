# The Archives' tiles kept current in every open market and shop page, one stream per locale: a bought copy lowers the stock everyone reads,
# an edition leaving the list takes its tiles away and has each market reload its panel to fill it again.
module ArchiveStream
  EVENTS = [ Game::Market::ArchivePurchased ].freeze

  BATCHES = :archive_stream_batches
  PANEL = "shop-panel-offers".freeze
  BATCH = AfterCommitBatch.new(BATCHES) { |card_season_ids| ArchiveStreamJob.perform_later(card_season_ids.uniq) }

  class << self
    def streamables(locale = I18n.locale) = [ "market-archive", locale.to_s ]

    def call(event)
      BATCH.add([ event.data[:card_season_id] ])
    end
  end
end
