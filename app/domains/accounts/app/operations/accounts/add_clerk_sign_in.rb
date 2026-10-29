module Accounts
  class AddClerkSignIn < ApplicationOperation
    def call(player:, session_token:)
      player = step require_player(player)
      client = ClerkClient.new
      claims = step client.verify_session(session_token)
      user = step client.user(claims.fetch("sub"))
      keys = ClerkIdentities.keys(user)
      email_hash = ClerkIdentities.email_hash(user)

      transaction do
        player.lock!("FOR NO KEY UPDATE")
        step require_player(player)
        step refuse_taken(player, keys + [ ClerkIdentities.email_key(user) ])
        keys.each do |provider, uid|
          step AddIdentity.new.call(player:, provider:, uid:, email_hash:) unless player.identities.exists?(provider:, uid:)
        end
        ClerkIdentities.stamp(player, user, keys + [ ClerkIdentities.email_key(user) ])
        player
      end
    end

    private

    def require_player(player)
      player.is_a?(Player) && player.persisted? && !player.removed? ? Success(player) : Failure(:player_required)
    end

    def refuse_taken(player, keys)
      taken = keys.any? { |provider, uid| Identity.where(provider:, uid:).where.not(player_id: player.id).exists? }
      taken ? Failure(:identity_taken) : Success(player)
    end
  end
end
