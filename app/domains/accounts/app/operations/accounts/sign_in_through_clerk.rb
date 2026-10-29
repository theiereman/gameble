module Accounts
  class SignInThroughClerk < ApplicationOperation
    def call(session_token:)
      client = ClerkClient.new
      claims = step client.verify_session(session_token)
      user = step client.user(claims.fetch("sub"))
      keys = ClerkIdentities.keys(user)
      email_hash = ClerkIdentities.email_hash(user)

      transaction do
        player = step existing_player(user, keys) || new_player(user, keys, email_hash)
        step refuse_banned(player)
        add_missing(player, keys.drop(1), email_hash)
        ClerkIdentities.stamp(player, user, keys + [ ClerkIdentities.email_key(user) ])
        player.update_columns(last_seen_at: Time.current)
        player
      end
    end

    private

    def existing_player(user, keys)
      (keys + [ ClerkIdentities.email_key(user) ]).each do |provider, uid|
        found = locked(PlayerByIdentity.call(provider:, uid:))
        return found if found
      end
      nil
    end

    def locked(player)
      return nil unless player

      player.lock!("FOR NO KEY UPDATE")
      player.deleted? ? nil : Success(player)
    end

    def new_player(user, keys, email_hash)
      ClerkIdentities.known_email_failure(user) || register(keys.first, email_hash)
    end

    def register(key, email_hash)
      provider, uid = key
      SignInThroughIdentity.new.call(provider:, uid:, email_hash:)
    end

    def refuse_banned(player)
      player.banned? ? Failure(:banned) : Success(player)
    end

    def add_missing(player, keys, email_hash)
      keys.each do |provider, uid|
        next if Identity.exists?(provider:, uid:)

        AddIdentity.new.call(player:, provider:, uid:, email_hash:)
      end
    end
  end
end
