module Accounts
  module BanReason
    LENGTH = 500

    def self.clean(value)
      return nil unless value.is_a?(String)

      reason = value.dup.force_encoding(Encoding::UTF_8).scrub("")
      reason = reason.gsub(PersonaName::INVISIBLE, "").gsub(PersonaName::SPACE, " ").squish
      reason if PersonaName::VISIBLE.match?(reason)
    end
  end
end
