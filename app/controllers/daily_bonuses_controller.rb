class DailyBonusesController < ApplicationController
  throttle_player to: 5, only: :create, path: -> { home_path }, alert: "daily_bonuses.create.throttled"

  def create
    authorize :daily_bonus, :create?

    result = Game::CollectDailyBonus.new.call(player: current_player)
    tone = result.success? ? :notice : :alert

    respond_to do |format|
      format.turbo_stream do
        @bank = Game::BankSummary.call(current_player)
        @message = helpers.local_time_sentence(@bank[:next_bonus_at]) { message(result, time: it) }
        @tone = tone
        @collected = result.success?
      end
      format.html { redirect_to home_path, tone => message(result, time: helpers.local_time_text(Game::BankSummary.next_bonus_at)), status: :see_other }
    end
  end

  private
    def message(result, time:)
      result.success? ? t("daily_bonuses.create.collected", time:) : Game::CollectDailyBonus.failure_message(result.failure, time:)
    end
end
