class LiveGoalJob < ApplicationJob
  queue_as :default

  def perform
    goal = Game::CurrentGoal.call
    I18n.available_locales.each do |locale|
      content = I18n.with_locale(locale) do
        ApplicationController.render(partial: "live_streams/goal", formats: [ :turbo_stream ], locals: { goal: })
      end
      Turbo::StreamsChannel.broadcast_stream_to(*LiveStream.goal_streamables(locale), content:)
    end
  end
end
