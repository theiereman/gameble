module Game
  class RenameCustomSet < Operation
    include CustomSetSteps

    def call(player:, token:, name:)
      player = step require_player(player)
      name = step clean_name(name)

      transaction do
        step lock_bank(player)
        custom_set = step locked_custom_set(player, token)
        step name_free(player, name, except: custom_set)
        custom_set.update!(name:)
        step published(CustomSetRenamed, player, custom_set)
        custom_set
      end
    end
  end
end
