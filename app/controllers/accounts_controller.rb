class AccountsController < ApplicationController
  rate_limit to: 5, within: 1.minute, only: :destroy,
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to settings_path, alert: t("accounts.destroy.throttled"), status: :see_other }

  # DELETE /:locale/account
  def destroy
    authorize :account, :destroy?
    unless confirmed?
      return redirect_to settings_path, alert: t(".wrong_word", word: t("accounts.dialog.word")), status: :see_other
    end

    reduced_motion = current_player.reduced_motion
    result = Accounts::DeletePlayer.new.call(player: current_player)
    if result.success?
      write_motion_cookie(reduced_motion)
      reset_session
      redirect_to home_path, notice: t(".deleted"), status: :see_other
    else
      redirect_to settings_path, alert: Accounts::DeletePlayer.failure_message(result.failure), status: :see_other
    end
  end

  private
    def confirmed?
      typed = params[:confirmation]
      typed.is_a?(String) && typed.strip.casecmp?(t("accounts.dialog.word"))
    end
end
