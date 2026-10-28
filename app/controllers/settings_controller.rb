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
    @card_count = Game::CollectionSummary.call(current_player).distinct_cards
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

  def cancels_unconfirmed_trades?
    params[:visibility] == "private" && !current_player.visibility_private? &&
      Game::OpenTradeCount.call(current_player) > params[:confirmed_trades].to_s.to_i
  end
end
