module Accounts
  class Announcement < ApplicationRecord
    self.table_name = "accounts_announcements"

    MESSAGE_LENGTH = 280

    has_secure_token :token, length: 24

    has_many :dismissals, class_name: "Accounts::AnnouncementDismissal", inverse_of: :announcement, dependent: nil

    scope :newest_first, -> { order(created_at: :desc, id: :desc) }

    def self.stream_name
      "Accounts::Announcements"
    end

    def self.clean(message)
      message.to_s.gsub(/\s+/, " ").strip
    end

    def self.valid_message?(message)
      message.length.between?(1, MESSAGE_LENGTH)
    end

    def to_param
      token
    end

    def message(locale = I18n.locale)
      locale.to_s == "fr" ? message_fr : message_en
    end
  end
end
