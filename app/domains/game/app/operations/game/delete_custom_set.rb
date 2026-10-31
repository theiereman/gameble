module Game
  class DeleteCustomSet < Operation
    include CustomSetSteps

    def call(player:, token:)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        custom_set = step locked_custom_set(player, token)
        CustomSet.where(id: custom_set.id).delete_all
        step published(CustomSetDeleted, player, custom_set)
        custom_set.name
      end
    end
  end
end
