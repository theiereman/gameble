module Accounts
  module EmailHash
    KEY_PURPOSE = "identity-email-hash"

    def self.call(address)
      return if address.blank?

      OpenSSL::HMAC.hexdigest("SHA256", key, EmailNormaliser.call(address))
    end

    def self.key
      Rails.application.key_generator.generate_key(KEY_PURPOSE)
    end
    private_class_method :key
  end
end
