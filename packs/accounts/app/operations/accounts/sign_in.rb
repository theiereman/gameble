module Accounts
  # Signs a player in by their Steam id (CAP-1, AD-14): reuses the player with
  # that id, or creates one and publishes Accounts::PlayerRegistered. A banned
  # player is refused.
  #
  #   Accounts::SignIn.new.call(steam_id: "76561197960287930")
  #   # => Success(player) | Failure(:invalid_steam_id) | Failure(:banned)
  class SignIn < ApplicationOperation
    def call(steam_id:)
      steam_id = step validate_steam_id(steam_id)

      transaction do
        player = step find_or_create_player(steam_id)
        step refuse_banned(player)
        if player.previously_new_record?
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

    # Two first sign-ins racing on the same Steam id meet the unique index:
    # create_or_find_by inserts in a savepoint and, on conflict, reads the
    # row the other one created.
    def find_or_create_player(steam_id)
      Success(Player.find_by(steam_id: steam_id) || Player.create_or_find_by!(steam_id: steam_id))
    end
  end
end
