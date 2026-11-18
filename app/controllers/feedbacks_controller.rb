class FeedbacksController < ApplicationController
  require_feature :duels
  throttle_player to: 10, only: :create, path: -> { home_path }, alert: "feedbacks.create.throttled"

  def new
    authorize :feedback, :new?
    @feature = known_feature
  end

  def create
    authorize :feedback, :create?
    feature = known_feature

    result = Accounts::SendFeedback.new.call(player: current_player, feature:, message: params[:message])
    if result.success?
      redirect_to origin(feature), notice: t(".sent"), status: :see_other
    else
      redirect_refused Accounts::SendFeedback, result, new_feedback_path(feature:)
    end
  end

  private
    def known_feature
      Accounts::Feedback::FEATURES.find { it == params[:feature].to_s } or raise ActiveRecord::RecordNotFound
    end

    def origin(feature)
      { "duels" => duels_path }.fetch(feature)
    end
end
