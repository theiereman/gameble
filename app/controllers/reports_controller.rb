class ReportsController < ApplicationController
  throttle_player to: 10, only: :create, path: -> { home_path }, alert: "reports.create.throttled"

  def create
    authorize :report, :create?

    reported = Accounts::PlayerByToken.call(params[:token])
    return render "public_profiles/unavailable", status: :not_found unless Game::Visibility.visible?(current_player, reported)

    result = Accounts::ReportPlayer.new.call(reporter: current_player, reported:, reason: params[:reason])
    back = params[:from] == "friends" ? friends_path : brother_path(token: reported.token)
    if result.success?
      redirect_to back, notice: t(".sent"), status: :see_other
    else
      redirect_refused Accounts::ReportPlayer, result, back
    end
  end
end
