class ReportsController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :create,
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to home_path, alert: t("reports.create.throttled"), status: :see_other }

  def create
    authorize :report, :create?

    reported = Accounts::PlayerByToken.call(params[:token])
    return render "public_profiles/unavailable", status: :not_found unless Game::Visibility.visible?(current_player, reported)

    result = Accounts::ReportPlayer.new.call(reporter: current_player, reported:, reason: params[:reason])
    back = params[:from] == "friends" ? friends_path : brother_path(token: reported.token)
    if result.success?
      redirect_to back, notice: t(".sent"), status: :see_other
    else
      redirect_to back, alert: Accounts::ReportPlayer.failure_message(result.failure), status: :see_other
    end
  end
end
