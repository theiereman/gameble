module Accounts
  class AddIdentity < ApplicationOperation
    def call(player:, provider:, uid:, email_hash: nil)
      player = step require_player(player)
      provider, uid = step validate_identity(provider, uid)

      transaction do
        player.lock!("FOR NO KEY UPDATE")
        step require_player(player)
        step refuse_taken(player, provider, uid)
        step refuse_known_email(player, email_hash)
        identity = step create_identity(player, provider, uid, email_hash)
        player.update!(steam_id: uid) if provider == "steam" && player.steam_id.nil?
        step publish(IdentityAdded.new(data: { player_id: player.id, provider: }), stream_name: "Accounts::Player$#{player.id}")
        identity
      end
    end

    private

    def require_player(player)
      player.is_a?(Player) && player.persisted? && !player.removed? ? Success(player) : Failure(:player_required)
    end

    def validate_identity(provider, uid)
      provider = provider.to_s
      return Failure(:invalid_identity) unless Identity::PROVIDERS.include?(provider)
      return Failure(:invalid_identity) unless uid.is_a?(String) && !uid.blank?
      return Failure(:invalid_identity) if provider == "steam" && !Player::STEAM_ID_FORMAT.match?(uid)

      Success([ provider, uid ])
    end

    def refuse_taken(player, provider, uid)
      taken = Identity.exists?(provider:, uid:) ||
        (provider == "steam" && (player.identities.exists?(provider:) || Player.where(steam_id: uid).where.not(id: player.id).exists?))
      taken ? Failure(:identity_taken) : Success(player)
    end

    def create_identity(player, provider, uid, email_hash)
      Identity.transaction(requires_new: true) { Success(player.identities.create!(provider:, uid:, email_hash: email_hash.presence)) }
    rescue ActiveRecord::RecordNotUnique
      Failure(:identity_taken)
    end

    def refuse_known_email(player, email_hash)
      return Success(player) if email_hash.blank?

      known = IdentityByEmailHash.call(email_hash)
      known && known.player_id != player.id ? Failure(:"email_known_#{known.provider}") : Success(player)
    end
  end
end
