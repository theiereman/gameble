module AnnouncementsHelper
  BANNER_ID = "announcement-banner"

  def announcement_banner
    return @announcement_banner if defined?(@announcement_banner)

    @announcement_banner = unless back_office_page?
      Accounts::AnnouncementBanner.for(player: current_player, closed_token: cookies[ApplicationController::CLOSED_ANNOUNCEMENT_COOKIE])
    end
  end
end
