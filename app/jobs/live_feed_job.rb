class LiveFeedJob < ApplicationJob
  queue_as :default

  def perform(notices)
    entries = Game::NewFeedEntries.call(pack_ids: notices.filter_map { it[:pack_id] },
      reposts: notices.select { it.key?(:card_season_id) }, trade_ids: notices.filter_map { it[:trade_id] },
      sets: notices.select { it.key?(:set_id) })
    return if entries.empty?

    latest = Game::FeedEntries.call(nil)
    strip = latest.first(LiveStream::STRIP_SIZE)
    preview = latest.first(LiveStream::SOCIAL_PREVIEW_SIZE)
    reactions = Game::FeedReactionSummaries.call((entries + preview).map { it.entry.id }.uniq)
    I18n.available_locales.each do |locale|
      broadcast(locale, entries, reactions, strip)
      broadcast_social_preview(locale, preview, reactions)
    end
  end

  private

  def broadcast(locale, entries, reactions, latest)
    items = FeedItems.call(entries, locale:)
    locals = { items:, reactions:, ticker: items.select { |item, _| LiveStream.ticker?(item) }, strip: FeedItems.call(latest, locale:) }
    content = I18n.with_locale(locale) do
      ApplicationController.render(partial: "live_streams/feed", formats: [ :turbo_stream ], locals:)
    end
    Turbo::StreamsChannel.broadcast_stream_to(*LiveStream.feed_streamables(locale), content:)
  end

  def broadcast_social_preview(locale, preview, reactions)
    locals = { items: FeedItems.call(preview, locale:), reactions:, lazy: true }
    content = I18n.with_locale(locale) do
      ApplicationController.render(partial: "live_streams/social_feed", formats: [ :turbo_stream ], locals:)
    end
    Turbo::StreamsChannel.broadcast_stream_to(*LiveStream.social_feed_streamables(locale), content:)
  end
end
