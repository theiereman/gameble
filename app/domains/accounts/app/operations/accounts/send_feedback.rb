module Accounts
  class SendFeedback < ApplicationOperation
    def call(player:, feature:, message:)
      player = step require_player(player)
      feature = step known_feature(feature)
      message = step check(message)

      transaction do
        feedback = Feedback.create!(player:, feature:, message:)
        step publish(FeedbackSent.new(data: { feedback_id: feedback.id, player_id: player.id, feature: }), stream_name: "Accounts::Player$#{player.id}")
        feedback
      end
    end

    private

    def require_player(player)
      player.is_a?(Player) && player.persisted? && !player.banned? ? Success(player) : Failure(:player_required)
    end

    def known_feature(feature)
      Feedback::FEATURES.include?(feature.to_s) ? Success(feature.to_s) : Failure(:unknown_feature)
    end

    def check(message)
      cleaned = Feedback.clean(message)
      Feedback.valid_message?(cleaned) ? Success(cleaned) : Failure(:invalid_feedback)
    end
  end
end
