module Game
  class CreateCustomSet < Operation
    include CustomSetSteps

    def call(player:, name:, card_ids:)
      player = step require_player(player)
      name = step clean_name(name)
      card_ids = step games_in_range(card_ids)
      step in_catalog(card_ids)

      transaction do
        step lock_bank(player)
        step room_left(player)
        step name_free(player, name)
        custom_set = CustomSet.create!(player_id: player.id, kind: CustomSet::CUSTOM, name:)
        insert_games(custom_set, card_ids)
        step published(CustomSetCreated, player, custom_set)
        custom_set
      end
    end

    private

    def room_left(player)
      CustomSet.custom.where(player_id: player.id).count < CustomSet::PER_PLAYER ? Success() : Failure(:too_many_sets)
    end
  end
end
