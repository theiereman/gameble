module Accounts
  module AnnouncementBanner
    # The shown announcement, unless this player closed it, or, for a visitor, unless it is the one their browser closed.
    def self.for(player:, closed_token: nil)
      shown = Announcement.where(shown: true)
      shown = if player
        shown.where.not(id: AnnouncementDismissal.where(player_id: player.id).select(:announcement_id))
      else
        shown.where.not(token: closed_token.to_s)
      end
      shown.take
    end
  end
end
