module Accounts
  module EmailNormaliser
    GMAIL_DOMAINS = %w[gmail.com googlemail.com].freeze

    def self.call(address)
      local, separator, domain = address.to_s.strip.downcase.rpartition("@")
      return domain if separator.empty?

      tagless = local.split("+", 2).first.to_s
      local = tagless.presence || local
      domain = "gmail.com" if GMAIL_DOMAINS.include?(domain)
      local = local.delete(".") if domain == "gmail.com"
      "#{local}@#{domain}"
    end
  end
end
