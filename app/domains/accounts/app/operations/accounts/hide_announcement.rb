module Accounts
  class HideAnnouncement < ApplicationOperation
    include AnnouncementWriting

    def call(staff:, announcement:)
      announcement = step require_announcement(announcement)

      transaction do
        one_writer_at_a_time
        step still_shown(announcement.reload)
        announcement.update!(shown: false)
        step publish_change(AnnouncementHidden.new(data: { announcement_id: announcement.id, staff_id: staff.id }))
        announcement
      end
    end

    private

    def still_shown(announcement)
      announcement.shown? ? Success() : Failure(:announcement_not_shown)
    end
  end
end
