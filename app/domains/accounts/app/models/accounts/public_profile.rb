require "digest"

module Accounts
  module PublicProfile
    CODE_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ".freeze
    CODE_LENGTH = 6

    def self.code(token)
      bits = Digest::SHA256.digest(token.to_s).unpack1("N") >> (32 - 5 * CODE_LENGTH)
      Array.new(CODE_LENGTH) { |index| CODE_ALPHABET[(bits >> (5 * (CODE_LENGTH - 1 - index))) & 0b11111] }.join
    end
  end
end
