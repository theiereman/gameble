require "digest"

module Accounts
  # The words of a player's public profile (CAP-8). The profile is reached by
  # the player's token, a public, non-secret handle. Whether it may be shown
  # is Game::Visibility's one question (AD-13), not asked here.
  #
  #   Accounts::PublicProfile.code(player.token) # => "7K2QXM"
  module PublicProfile
    # Crockford's base32 alphabet: no I, L, O or U.
    CODE_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ".freeze
    CODE_LENGTH = 6

    # A short code naming a player who has no persona name: the first six
    # Crockford base32 characters of SHA-256(token), from the digest's
    # leading 30 bits. Stable for a token; it reveals neither the token nor
    # any id.
    def self.code(token)
      bits = Digest::SHA256.digest(token.to_s).unpack1("N") >> (32 - 5 * CODE_LENGTH)
      Array.new(CODE_LENGTH) { |index| CODE_ALPHABET[(bits >> (5 * (CODE_LENGTH - 1 - index))) & 0b11111] }.join
    end
  end
end
