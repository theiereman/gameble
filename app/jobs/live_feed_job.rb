class LiveFeedJob < ApplicationJob
  queue_as :default

  def perform(notices)
    entries = Game::NewFeedEntries.call(pack_ids: notices.filter_map { it[:pack_id] },
      reposts: notices.select { it.key?(:card_season_id) }, trade_ids: notices.filter_map { it[:trade_id] },
      sets: notices.select { it.key?(:set_id) }, listing_ids: notices.filter_map { it[:listing_id] })
    return if entries.empty?

    strip = Game::FeedEntries.call(nil).first(LiveStream::STRIP_SIZE)
    reactions = Game::FeedReactionSummaries.call(entries.map { it.entry.id })
    I18n.available_locales.each { broadcast(it, entries, reactions, strip) }
  end

  private

  def broadcast(locale, entries, reactions, strip)
    items = FeedItems.call(entries, locale:)
    locals = { items:, reactions:, ticker: items.select { |item, _| LiveStream.ticker?(item) }, strip: FeedItems.call(strip, locale:) }
    content = I18n.with_locale(locale) do
      ApplicationController.render(partial: "live_streams/feed", formats: [ :turbo_stream ], locals:)
    end
    Turbo::StreamsChannel.broadcast_stream_to(*LiveStream.feed_streamables(locale), content:)
  end
end
