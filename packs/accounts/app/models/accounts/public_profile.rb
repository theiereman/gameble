require "digest"

module Accounts
  # What may be shown of a player's public profile (CAP-8). The profile is
  # reached by the player's token, a public, non-secret handle; it is shown
  # to anyone, signed out included, unless the player is banned (epic 7 adds
  # hidden and deleted profiles, a hidden one still shown to its owner).
  #
  #   Accounts::PublicProfile.visible?(player, viewer: current_player) # => true | false
  #   Accounts::PublicProfile.code(player.token)                       # => "7K2QXM"
  module PublicProfile
    # Crockford's base32 alphabet: no I, L, O or U.
    CODE_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ".freeze
    CODE_LENGTH = 6

    # False for no player or a banned one. The viewer (nil for a visitor)
    # matters once a profile can be hidden from all but its owner.
    def self.visible?(player, viewer:)
      player.present? && !player.banned?
    end

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
