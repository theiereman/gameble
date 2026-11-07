module Accounts
  class ShowAnnouncement < ApplicationOperation
    include AnnouncementWriting

    def call(staff:, announcement:)
      announcement = step require_announcement(announcement)

      transaction do
        one_writer_at_a_time
        hide_shown_announcements
        announcement.update!(shown: true)
        step publish_change(AnnouncementShown.new(data: { announcement_id: announcement.id, staff_id: staff.id }))
        announcement
      end
    end
  end
end
