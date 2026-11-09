module Accounts
  module Announcements
    def self.newest_first
      Announcement.newest_first.to_a
    end

    def self.any_shown?
      Announcement.exists?(shown: true)
    end

    def self.by_token(token)
      Announcement.find_by(token: token.to_s)
    end

    def self.dismissal_counts(announcements)
      AnnouncementDismissal.where(announcement_id: announcements.map(&:id)).group(:announcement_id).count
    end
  end
end
