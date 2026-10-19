# Collecting the daily booster from the hub's panel (CAP-16): the bonus pack
# joins the reserve. From the hub the claim answers in Turbo Stream, which
# replaces the panel, the packs chip, menu 01, the empty showcase's action
# and, once the reserve is full, a waiting goal reward's claim slot, and adds
# a toast (bonus_arc_controller.ts flies the canister from the
# `turbo:before-stream-render`), whose time of the next booster reads in the
# player's own time; without JavaScript it redirects to the hub, the time in
# UTC.
# A refusal answers the same way, with the panel as the server shows it.
class DailyBonusesController < ApplicationController
  rate_limit to: 5, within: 1.minute, only: :create,
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to home_path, alert: t("daily_bonuses.create.throttled"), status: :see_other }

  # POST /:locale/daily-bonus
  def create
    authorize :daily_bonus, :create?

    result = Game::CollectDailyBonus.new.call(player: current_player)
    tone = result.success? ? :notice : :alert

    respond_to do |format|
      format.turbo_stream do
        @bank = Game::BankSummary.call(current_player)
        @goal_reward = Game::GoalRewardStatus.call(current_player) if @bank[:reserve_full]
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
