class AnnouncementDismissalsController < ApplicationController
  rate_limit to: 30, within: 1.minute, by: -> { current_player&.id || request.remote_ip }, with: -> { head :too_many_requests }

  def create
    authorize :announcement_dismissal, :create?
    announcement = Accounts::Announcements.by_token(params[:token]) or raise ActiveRecord::RecordNotFound

    if current_player
      Accounts::DismissAnnouncement.new.call(player: current_player, announcement:)
    else
      write_closed_announcement_cookie(announcement.token)
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(AnnouncementsHelper::BANNER_ID) }
      format.html { redirect_back_or_to home_path, status: :see_other }
    end
  end
end
