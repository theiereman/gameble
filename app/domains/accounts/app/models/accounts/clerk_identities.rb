module Accounts
  module ClerkIdentities
    def self.keys(user)
      accounts = user.external_accounts.select(&:verified).map { [ it.provider, it.uid ] }.uniq
      accounts.presence || [ [ "email", user.id ] ]
    end

    def self.email_hash(user)
      EmailHash.call(user.primary_verified_email)
    end

    # The key an email-code user is found through, even when external accounts were attached since.
    def self.email_key(user)
      [ "email", user.id ]
    end

    def self.stamp(player, user, keys)
      matching = keys.map { |provider, uid| Identity.where(provider:, uid:) }.reduce(:or)
      Identity.where(player_id: player.id, clerk_user_id: nil).merge(matching).update_all(clerk_user_id: user.id)
    end
  end
end
