module Accounts
  class PushDevice < ApplicationRecord
    self.table_name = "accounts_push_devices"

    PLATFORMS = %w[apple google].freeze
    TOKEN_LENGTH = 4096

    belongs_to :player, class_name: "Accounts::Player"

    validates :platform, inclusion: { in: PLATFORMS }
    validates :token, presence: true, length: { maximum: TOKEN_LENGTH }
    validates :locale, inclusion: { in: -> { I18n.available_locales.map(&:to_s) } }

    def push(notification)
      notification.token = token
      ActionPushNative.service_for(platform, notification).push(notification)
    rescue ActionPushNative::TokenError
      ForgetPushDevice.new.call(token:)
    end
  end
end
