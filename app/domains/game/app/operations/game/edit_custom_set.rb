module Game
  class EditCustomSet < Operation
    include CustomSetSteps

    def call(player:, token:, name:, card_ids:)
      player = step require_player(player)
      name = step clean_name(name)
      card_ids = step games_in_range(card_ids)
      step in_catalog(card_ids)

      transaction do
        step lock_bank(player)
        custom_set = step locked_custom_set(player, token)
        step name_free(player, name, except: custom_set)
        custom_set.update!(name:)
        CustomSetGame.where(custom_set_id: custom_set.id).delete_all
        insert_games(custom_set, card_ids)
        step published(CustomSetEdited, player, custom_set)
        custom_set
      end
    end
  end
end
