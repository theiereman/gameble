module Accounts
  # Signs a player in by their Steam id: reuses the player with
  # that id, or creates one, its welcome panel pending, and publishes
  # Accounts::PlayerRegistered. A banned player is refused.
  #
  # The persona name the web layer read from Steam for this sign-in
  # becomes the player's display name: cleaned by Accounts::PersonaName
  # (invisible characters dropped, spaces squished, cut to
  # Accounts::PersonaName::LENGTH graphemes), it replaces a different
  # stored one, so a renamed Steam account is picked up here; nil, or a name
  # that cleans to nothing, keeps the stored name (Steam failed or gave none
  # worth showing). Accounts never calls Steam itself.
  #
  #   Accounts::SignIn.new.call(steam_id: "76561197960287930", persona_name: "Gabe")
  #   # => Success(player) | Failure(:invalid_steam_id) | Failure(:banned)
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
      # Control characters (a NUL byte would fail the write) are dropped
      # with the other invisible ones.
      name = PersonaName.clean(persona_name)
      player.update!(persona_name: name) if name && name != player.persona_name
      Success(player)
    end

    # Two first sign-ins racing on the same Steam id meet the unique index:
    # create_or_find_by inserts in a savepoint and, on conflict, reads the
    # row the other one created. A row found while a deletion held it has
    # released its Steam id: the sign-in then signs up anew.
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
