class SettingsController < ApplicationController
  MOTION_CHOICES = { "system" => nil, "on" => true, "off" => false }.freeze

  def show
    authorize :settings, :show?
    @reduced_motion = current_player.reduced_motion
    @visibility = current_player.visibility
    @last_export = Accounts::LastExportOf.call(current_player)
    @next_export_at = current_player.next_export_at
    @open_trades = Game::OpenTradeCount.call(current_player)
    @asks_to_go_private = flash[:confirm_private].present?
    @identities = Accounts::IdentitiesOf.call(current_player)
    @clerk_mode = params[:add_sign_in].present? ? "callback" : "start"
  end

  def visibility
    authorize :settings, :visibility?

    return redirect_to(settings_path, flash: { confirm_private: true }, status: :see_other) if cancels_unconfirmed_trades?

    result = Accounts::SetVisibility.new.call(player: current_player, visibility: params[:visibility])
    if result.success?
      redirect_to settings_path, status: :see_other
    else
      redirect_refused Accounts::SetVisibility, result, settings_path
    end
  end

  def name
    authorize :settings, :name?

    result = Accounts::ChangePersonaName.new.call(player: current_player, name: params[:name])
    if result.success?
      redirect_to own_profile_path, status: :see_other
    else
      redirect_refused Accounts::ChangePersonaName, result, own_profile_path
    end
  end

  def update
    authorize :settings, :update?

    result = Accounts::UpdateSettings.new.call(player: current_player, reduced_motion: MOTION_CHOICES.fetch(params[:reduced_motion].to_s, :invalid))
    if result.success?
      write_motion_cookie(result.value!.reduced_motion)
      redirect_to settings_path, status: :see_other
    else
      redirect_refused Accounts::UpdateSettings, result, settings_path
    end
  end

  private

  def own_profile_path
    brother_path(token: current_player.token)
  end

  def cancels_unconfirmed_trades?
    params[:visibility] == "private" && !current_player.visibility_private? &&
      Game::OpenTradeCount.call(current_player) > params[:confirmed_trades].to_s.to_i
  end
end
