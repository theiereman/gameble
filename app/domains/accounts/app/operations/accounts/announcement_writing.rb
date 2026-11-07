module Accounts
  module AnnouncementWriting
    private

    def validate_messages(message_fr:, message_en:)
      messages = { message_fr: Announcement.clean(message_fr), message_en: Announcement.clean(message_en) }
      messages.values.all? { Announcement.valid_message?(it) } ? Success(messages) : Failure(:invalid_announcement)
    end

    def require_announcement(announcement)
      announcement.is_a?(Announcement) && announcement.persisted? ? Success(announcement) : Failure(:announcement_not_found)
    end

    def one_writer_at_a_time
      Announcement.connection.execute("SELECT pg_advisory_xact_lock(hashtext('#{Announcement.table_name}'))")
    end

    def hide_shown_announcements
      Announcement.where(shown: true).update_all(shown: false, updated_at: Time.current)
    end

    def publish_change(event)
      publish(event, stream_name: Announcement.stream_name)
    end
  end
end
