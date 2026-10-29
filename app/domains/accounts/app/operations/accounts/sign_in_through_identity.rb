module Accounts
  class SignInThroughIdentity < ApplicationOperation
    def call(provider:, uid:, persona_name: nil, email_hash: nil)
      provider, uid = step validate_identity(provider, uid)

      transaction do
        player = step find_or_register(provider, uid, email_hash)
        step refuse_banned(player)
        step store_persona_name(player, persona_name) if provider == "steam"
        player.update_columns(last_seen_at: Time.current)
        step publish_registration(player) if @registered
        player
      end
    end

    private

    def validate_identity(provider, uid)
      provider = provider.to_s
      return Failure(:invalid_identity) unless Identity::PROVIDERS.include?(provider)

      if provider == "steam"
        return Failure(:invalid_steam_id) unless uid.is_a?(String) && Player::STEAM_ID_FORMAT.match?(uid)
      elsif !uid.is_a?(String) || uid.blank?
        return Failure(:invalid_identity)
      end

      Success([ provider, uid ])
    end

    def find_or_register(provider, uid, email_hash)
      @registered = false
      player = locked_owner(Identity.find_by(provider:, uid:)&.player, provider, uid)
      player ||= locked_owner(adopt_steam_player(provider, uid), provider, uid)
      return Success(player) if player

      known = IdentityByEmailHash.call(email_hash) if email_hash.present?
      return Failure(:"email_known_#{known.provider}") if known

      Success(register(provider, uid, email_hash))
    end

    def adopt_steam_player(provider, uid)
      return nil unless provider == "steam"

      player = Player.find_by(steam_id: uid)
      return nil unless player

      lock(player)
      return nil if player.deleted? || player.steam_id != uid

      player.identities.find_or_create_by!(provider:, uid:)
      player
    end

    def lock(player)
      player.lock!("FOR NO KEY UPDATE")
      player
    end

    def locked_owner(player, provider, uid)
      return nil unless player

      lock(player)
      player if !player.deleted? && Identity.exists?(player_id: player.id, provider:, uid:)
    end

    def register(provider, uid, email_hash)
      player = provider == "steam" ? steam_player(uid) : handle_player
      @registered = player.previously_new_record?
      identity = Identity.create_or_find_by!(provider:, uid:) do
        it.player = player
        it.email_hash = email_hash
      end
      return player if identity.player_id == player.id

      player.delete if @registered
      @registered = false
      lock(identity.player)
    end

    def steam_player(uid)
      Player.create_or_find_by!(steam_id: uid) { it.welcome_pending = true }
    end

    def handle_player
      Player.create!(persona_name: HandleGenerator.call, welcome_pending: true)
    end

    def refuse_banned(player)
      player.banned? ? Failure(:banned) : Success(player)
    end

    def store_persona_name(player, persona_name)
      name = PersonaName.clean(persona_name)
      player.update!(persona_name: name) if name && name != player.persona_name
      Success(player)
    end

    def publish_registration(player)
      publish(PlayerRegistered.new(data: { player_id: player.id }), stream_name: "Accounts::Player$#{player.id}")
    end
  end
end
