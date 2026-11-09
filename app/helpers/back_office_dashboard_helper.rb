module BackOfficeDashboardHelper
  Tile = Data.define(:key, :href, :status, :turbo)
  Status = Data.define(:label, :tone, :urgent)

  def back_office_groups
    {
      moderation: [
        back_office_tile(:reports, back_office_reports_path, status: reports_status),
        back_office_tile(:players, back_office_players_path),
        back_office_tile(:bans, back_office_bans_path),
        back_office_tile(:history, back_office_history_path)
      ],
      catalog: [
        back_office_tile(:import_runs, back_office_import_runs_path, status: import_status),
        back_office_tile(:seasons, back_office_seasons_path),
        back_office_tile(:themes, back_office_themes_path, status: themes_status),
        back_office_tile(:cards, back_office_cards_path)
      ],
      communication: [
        back_office_tile(:release_notes, back_office_release_notes_path, status: release_note_status),
        back_office_tile(:announcements, back_office_announcements_path, status: announcement_status),
        back_office_tile(:roadmap, back_office_roadmap_path, action: :show?)
      ],
      technical: [
        back_office_tile(:jobs, mission_control_jobs.root_path(locale: nil), action: :show?, turbo: false)
      ]
    }.transform_values(&:compact).reject { |_, tiles| tiles.empty? }
  end

  private
    def back_office_tile(key, href, action: :index?, status: nil, turbo: true)
      Tile.new(key:, href:, status:, turbo:) if policy([ :back_office, key ]).public_send(action)
    end

    def reports_status
      Status.new(dashboard_status(:reports, count: @queue_size), :count, true) if @queue_size.positive?
    end

    def themes_status
      Status.new(dashboard_status(:themes, count: @unclassified_tags), :count, false) if @unclassified_tags.to_i.positive?
    end

    def import_status
      if @import_run&.ready?
        Status.new(dashboard_status(:import_ready), :alert, true)
      elsif @import_run&.active?
        Status.new(dashboard_status(:import_running), :live, false)
      end
    end

    def release_note_status
      version = release_note_missing or return
      Status.new(dashboard_status(:release_note_missing, version:), :alert, true)
    end

    def announcement_status
      Status.new(dashboard_status(:announcement_shown), :live, false) if @announcement_shown
    end

    def dashboard_status(key, **)
      t("back_office.dashboard.show.status.#{key}", **)
    end
end
