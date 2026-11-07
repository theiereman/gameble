module Accounts
  class CreateAnnouncement < ApplicationOperation
    include AnnouncementWriting

    def call(staff:, message_fr:, message_en:, shown:)
      messages = step validate_messages(message_fr:, message_en:)

      transaction do
        one_writer_at_a_time
        hide_shown_announcements if shown
        announcement = Announcement.create!(**messages, shown:)
        step publish_change(AnnouncementCreated.new(data: { announcement_id: announcement.id, staff_id: staff.id, shown: }))
        announcement
      end
    end
  end
end
