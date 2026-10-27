module Accounts
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
