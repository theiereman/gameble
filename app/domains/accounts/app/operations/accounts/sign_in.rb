module Accounts
  class SignIn < ApplicationOperation
    def call(steam_id:, persona_name: nil)
      steam_id = step validate_steam_id(steam_id)

      transaction do
        player = step find_or_create_player(steam_id)
        step refuse_banned(player)
        registered = player.previously_new_record?
        step store_persona_name(player, persona_name)
        player.update_columns(last_seen_at: Time.current)
        if registered
          step publish(PlayerRegistered.new(data: { player_id: player.id }), stream_name: "Accounts::Player$#{player.id}")
        end
        player
      end
    end

    private

    def validate_steam_id(steam_id)
      if steam_id.is_a?(String) && Player::STEAM_ID_FORMAT.match?(steam_id)
        Success(steam_id)
      else
        Failure(:invalid_steam_id)
      end
    end

    def refuse_banned(player)
      player.banned? ? Failure(:banned) : Success(player)
    end

    def store_persona_name(player, persona_name)
      name = PersonaName.clean(persona_name)
      player.update!(persona_name: name) if name && name != player.persona_name
      Success(player)
    end

    def find_or_create_player(steam_id)
      Success(lock_if_still_owner(Player.find_by(steam_id: steam_id), steam_id) || Player.create_or_find_by!(steam_id: steam_id) { it.welcome_pending = true })
    end

    def lock_if_still_owner(player, steam_id)
      return nil unless player

      player.lock!("FOR NO KEY UPDATE")
      player if player.steam_id == steam_id
    end
  end
end
