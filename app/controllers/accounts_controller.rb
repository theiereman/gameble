class AccountsController < ApplicationController
  throttle_player to: 5, only: :destroy, path: -> { settings_path }, alert: "accounts.destroy.throttled"

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
      redirect_refused Accounts::DeletePlayer, result, settings_path
    end
  end

  private
    def confirmed?
      typed = params[:confirmation]
      typed.is_a?(String) && typed.strip.casecmp?(t("accounts.dialog.word"))
    end
end
