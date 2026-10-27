module Accounts
  # Updates a player's settings (EXPERIENCE.md, Profil et paramètres). Today
  # one: "Animations réduites" (`reduced_motion`), true to force reduced
  # motion, false for an explicit "no", nil to follow the system's
  # preference (the default, and what "SYSTÈME" stores). A setting left out
  # is left as it was. Housekeeping: it publishes no event (AD-10).
  #
  #   Accounts::UpdateSettings.new.call(player:, reduced_motion: true)
  #   # => Success(player) | Failure(:player_required) | Failure(:invalid_setting)
  class UpdateSettings < ApplicationOperation
    UNSET = Object.new.freeze
    private_constant :UNSET

    def call(player:, reduced_motion: UNSET)
      player = step require_player(player)
      attributes = step check(reduced_motion)

      transaction do
        player.update!(attributes)
        player
      end
    end

    private

    def require_player(player)
      player.is_a?(Player) && player.persisted? && !player.banned? ? Success(player) : Failure(:player_required)
    end

    def check(reduced_motion)
      return Success({}) if UNSET.equal?(reduced_motion)

      [ true, false, nil ].include?(reduced_motion) ? Success({ reduced_motion: }) : Failure(:invalid_setting)
    end
  end
end
