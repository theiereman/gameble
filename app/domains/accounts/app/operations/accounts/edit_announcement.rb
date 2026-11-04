module Accounts
  class EditAnnouncement < ApplicationOperation
    include AnnouncementWriting

    def call(staff:, announcement:, message_fr:, message_en:)
      announcement = step require_announcement(announcement)
      messages = step validate_messages(message_fr:, message_en:)

      transaction do
        announcement.lock!
        announcement.update!(messages)
        step publish_change(AnnouncementEdited.new(data: { announcement_id: announcement.id, staff_id: staff.id }))
        announcement
      end
    end
  end
end
