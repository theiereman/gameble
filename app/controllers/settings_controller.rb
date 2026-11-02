class SettingsController < ApplicationController
  MOTION_CHOICES = { "system" => nil, "on" => true, "off" => false }.freeze
  LIBRARY_SYNC_CHOICES = { "on" => true, "off" => false }.freeze

  throttle_player to: 1, within: 5.minutes, only: :sync_steam_library, path: -> { settings_path }, alert: "settings.sync_library.throttled"

  def show
    authorize :settings, :show?
    @reduced_motion = current_player.reduced_motion
    @visibility = current_player.visibility
    @last_export = Accounts::LastExportOf.call(current_player)
    @next_export_at = current_player.next_export_at
    @open_trades = Game::OpenTradeCount.call(current_player)
    @asks_to_go_private = flash[:confirm_private].present?
    @card_count = Game::CollectionSummary.call(current_player).distinct_cards
    @active_title = Game::ActiveProfileTitle.call(current_player)
    @identities = Accounts::IdentitiesOf.call(current_player)
    steam_linked = @identities.any? { it.provider == "steam" }
    @name_editable = !steam_linked
    @library_sync = current_player.steam_library_sync if steam_linked
    @library_synced_at = Game::LibrarySyncedAt.call(current_player) if steam_linked
    @asks_to_turn_library_off = flash[:confirm_library_off].present?
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

  def steam_library
    authorize :settings, :steam_library?
    enabled = LIBRARY_SYNC_CHOICES.fetch(params[:steam_library_sync].to_s, :invalid)

    return redirect_to(settings_path, flash: { confirm_library_off: true }, status: :see_other) if erases_library_unconfirmed?(enabled)

    result = Accounts::SetSteamLibrarySync.new.call(player: current_player, enabled:)
    if result.success?
      CreateSteamLibrarySetJob.perform_later(current_player.id, first_sync: true) if turned_on?(result.value!)
      redirect_to settings_path, status: :see_other
    else
      redirect_refused Accounts::SetSteamLibrarySync, result, settings_path
    end
  end

  def sync_steam_library
    authorize :settings, :sync_steam_library?

    if syncs_library?
      CreateSteamLibrarySetJob.perform_later(current_player.id, first_sync: true)
      redirect_to settings_path, notice: t("settings.sync_library.started"), status: :see_other
    else
      redirect_to settings_path, alert: t("settings.sync_library.unavailable"), status: :see_other
    end
  end

  def name
    authorize :settings, :name?

    result = Accounts::ChangePersonaName.new.call(player: current_player, name: params[:name])
    if result.success?
      redirect_to settings_path, status: :see_other
    else
      redirect_refused Accounts::ChangePersonaName, result, settings_path
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

  def turned_on?(player)
    player.saved_change_to_steam_library_sync? && player.steam_library_sync
  end

  def syncs_library?
    current_player.steam_library_sync && Accounts::SteamIdOf.call(current_player).present?
  end

  def erases_library_unconfirmed?(enabled)
    enabled == false && current_player.steam_library_sync && params[:confirmed] != "1" && Accounts::SteamIdOf.call(current_player).present?
  end
end
