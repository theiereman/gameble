# Collecting the daily booster from the hub's panel (CAP-16): the bonus pack
# joins the reserve, and the player is sent back to the hub.
class DailyBonusesController < ApplicationController
  rate_limit to: 5, within: 1.minute, only: :create,
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to home_path, alert: t("daily_bonuses.create.throttled"), status: :see_other }

  # POST /:locale/daily-bonus
  def create
    authorize :daily_bonus, :create?

    result = Game::CollectDailyBonus.new.call(player: current_player)
    if result.success?
      redirect_to home_path, notice: t(".collected"), status: :see_other
    else
      redirect_to home_path, alert: Game::CollectDailyBonus.failure_message(result.failure), status: :see_other
    end
  end
end
