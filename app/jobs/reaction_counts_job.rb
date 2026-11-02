class ReactionCountsJob < ApplicationJob
  queue_as :default

  def perform(entry_ids)
    tokens = Game::FeedEntry.where(id: entry_ids).pluck(:id, :token).to_h
    summaries = Game::FeedReactionSummaries.call(tokens.keys)
    content = ApplicationController.render(partial: "reactions/counts", formats: [ :turbo_stream ],
      locals: { counts: tokens.to_h { |id, token| [ token, summaries.fetch(id).counts ] } })
    Turbo::StreamsChannel.broadcast_stream_to(*ReactionStream.streamables, content:)
  end
end
