# Collecting the daily booster from the hub's panel (CAP-16): the bonus pack
# joins the reserve. From the hub the claim answers in Turbo Stream, which
# replaces the panel, the packs chip, menu 01 and the empty showcase's action
# and adds a toast (bonus_arc_controller.ts flies the canister from the
# `turbo:before-stream-render`); without JavaScript it redirects to the hub.
# A refusal answers the same way, with the panel as the server shows it.
class DailyBonusesController < ApplicationController
  rate_limit to: 5, within: 1.minute, only: :create,
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to home_path, alert: t("daily_bonuses.create.throttled"), status: :see_other }

  # POST /:locale/daily-bonus
  def create
    authorize :daily_bonus, :create?

    result = Game::CollectDailyBonus.new.call(player: current_player)
    message = result.success? ? t(".collected") : Game::CollectDailyBonus.failure_message(result.failure)
    tone = result.success? ? :notice : :alert

    respond_to do |format|
      format.turbo_stream do
        @bank = Game::BankSummary.call(current_player)
        @message = message
        @tone = tone
        @collected = result.success?
      end
      format.html { redirect_to home_path, tone => message, status: :see_other }
    end
  end
end
