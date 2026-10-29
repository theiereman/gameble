module Accounts
  module IdentityByEmailHash
    def self.call(hash)
      return nil if hash.blank?

      Identity.find_by(email_hash: hash)
    end
  end
end
