class SettingsController < ApplicationController
  # The motion choices the form posts: SYSTÈME (nil, follow the system),
  # OUI (reduced) and NON (an explicit no). Anything else is refused.
  MOTION_CHOICES = { "system" => nil, "on" => true, "off" => false }.freeze

  # GET /:locale/settings
  def show
    authorize :settings, :show?
    @reduced_motion = current_player.reduced_motion
    @visibility = current_player.visibility
    @last_export = Accounts::LastExportOf.call(current_player)
    @next_export_at = current_player.next_export_at
    @open_trades = Game::OpenTradeCount.call(current_player)
  end

  # PATCH /:locale/settings/visibility
  def visibility
    authorize :settings, :visibility?

    visibility = params[:visibility]
    becoming_private = visibility == "private" && !current_player.visibility_private?
    open_trades_before = becoming_private ? Game::OpenTradeCount.call(current_player) : 0
    result = Accounts::SetVisibility.new.call(player: current_player, visibility:)
    if result.success?
      redirect_to settings_path, notice: t("settings.visibility_feedback.#{result.value!.visibility}", count: open_trades_before), status: :see_other
    else
      redirect_to settings_path, alert: Accounts::SetVisibility.failure_message(result.failure), status: :see_other
    end
  end

  # PATCH /:locale/settings
  def update
    authorize :settings, :update?

    result = Accounts::UpdateSettings.new.call(player: current_player, reduced_motion: MOTION_CHOICES.fetch(params[:reduced_motion].to_s, :invalid))
    if result.success?
      write_motion_cookie(result.value!.reduced_motion)
      redirect_to settings_path, status: :see_other
    else
      redirect_to settings_path, alert: Accounts::UpdateSettings.failure_message(result.failure), status: :see_other
    end
  end
end
