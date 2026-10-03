module Accounts
  # Signs a player in by their Steam id (CAP-1, AD-14): reuses the player with
  # that id, or creates one and publishes Accounts::PlayerRegistered. A banned
  # player is refused.
  #
  # The persona name the web layer read from Steam for this sign-in (CAP-8)
  # becomes the player's display name: a present one, stripped and cut to
  # PERSONA_NAME_LENGTH characters, replaces a different stored one, so a
  # renamed Steam account is picked up here; nil or blank keeps the stored
  # name (Steam failed or gave none). Accounts never calls Steam itself.
  #
  #   Accounts::SignIn.new.call(steam_id: "76561197960287930", persona_name: "Gabe")
  #   # => Success(player) | Failure(:invalid_steam_id) | Failure(:banned)
  class SignIn < ApplicationOperation
    PERSONA_NAME_LENGTH = 64

    def call(steam_id:, persona_name: nil)
      steam_id = step validate_steam_id(steam_id)

      transaction do
        player = step find_or_create_player(steam_id)
        step refuse_banned(player)
        registered = player.previously_new_record?
        step store_persona_name(player, persona_name)
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
      # Control characters (a NUL byte would fail the write) are dropped.
      name = persona_name.gsub(/[[:cntrl:]]/, "").strip.first(PERSONA_NAME_LENGTH).strip if persona_name.is_a?(String)
      player.update!(persona_name: name) if name.present? && name != player.persona_name
      Success(player)
    end

    # Two first sign-ins racing on the same Steam id meet the unique index:
    # create_or_find_by inserts in a savepoint and, on conflict, reads the
    # row the other one created.
    def find_or_create_player(steam_id)
      Success(Player.find_by(steam_id: steam_id) || Player.create_or_find_by!(steam_id: steam_id))
    end
  end
end
