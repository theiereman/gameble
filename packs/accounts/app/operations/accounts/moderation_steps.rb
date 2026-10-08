module Accounts
  module ModerationSteps
    private

    def require_staff(actor)
      actor.is_a?(Player) && actor.persisted? && actor.staff? && !actor.removed? ? Success(actor) : Failure(:staff_required)
    end

    def reread_staff(actor)
      require_staff(Player.find_by(id: actor.id))
    end

    def require_target(player)
      player.is_a?(Player) && player.persisted? && !player.deleted? ? Success(player) : Failure(:player_not_found)
    end

    def lock_target(player)
      player.lock!("FOR NO KEY UPDATE")
      require_target(player)
    end
  end
end
