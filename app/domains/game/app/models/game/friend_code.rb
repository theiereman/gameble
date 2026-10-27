module Game
  class FriendCode < ApplicationRecord
    self.table_name = "game_friend_codes"

    ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ".chars.freeze
    FORMAT = /\A[2-9A-HJKMNP-Z]{4}-[2-9A-HJKMNP-Z]{4}\z/

    def self.random_code
      Array.new(8) { ALPHABET[SecureRandom.random_number(ALPHABET.size)] }.each_slice(4).map(&:join).join("-")
    end
  end
end
