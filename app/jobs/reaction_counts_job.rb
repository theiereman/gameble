class ReactionCountsJob < ApplicationJob
  queue_as :default

  def perform(entry_ids)
    tokens = Game::FeedEntry.where(id: entry_ids).pluck(:id, :token).to_h
    summaries = Game::FeedReactionSummaries.call(tokens.keys)
    by_token = tokens.to_h { |id, token| [ token, summaries.fetch(id) ] }
    I18n.available_locales.each { broadcast(it, by_token) }
  end

  private
    def broadcast(locale, summaries)
      content = I18n.with_locale(locale) do
        ApplicationController.render(partial: "reactions/counts", formats: [ :turbo_stream ], locals: { summaries: })
      end
      Turbo::StreamsChannel.broadcast_stream_to(*ReactionStream.streamables(locale), content:)
    end
end
