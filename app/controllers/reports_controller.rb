# Reporting a player's profile (CAP-15, R4, story 7.4): the report dialog of
# the public profile posts here, by the profile's token (AD-15). Anonymous to
# the reported player: the answer is the same thank-you whatever a repeat or
# a hidden profile would say, and nothing is published to them. The reason
# is Accounts::ReportPlayer's to judge. A profile the reporter may not see
# is the unavailable page with a 404, as the profile itself (a report cannot
# probe a hidden player). A visitor is refused by the policy and sent to the
# sign-in; each player is limited per minute here and per day by the
# operation. A report sent from a friend's profile (`from=friends`, story
# 5.10) comes back to the Friends screen, any other to the profile.
class ReportsController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :create,
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to home_path, alert: t("reports.create.throttled"), status: :see_other }

  # POST /:locale/brothers/:token/report
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
