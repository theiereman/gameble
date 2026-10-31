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
        CustomSetGame.insert_all!(card_ids.map { |card_id| { custom_set_id: custom_set.id, card_id: } })
        step published(CustomSetCreated, player, custom_set)
        custom_set
      end
    end

    private

    def games_in_range(card_ids)
      card_ids = Array(card_ids).uniq
      if card_ids.size < CustomSet::GAMES.min
        Failure(:too_few_games)
      elsif card_ids.size > CustomSet::GAMES.max
        Failure(:too_many_games)
      else
        Success(card_ids)
      end
    end

    def in_catalog(card_ids)
      Catalog::PublishedCardIds.within(card_ids).size == card_ids.size ? Success() : Failure(:game_not_in_catalog)
    end

    def room_left(player)
      CustomSet.custom.where(player_id: player.id).count < CustomSet::PER_PLAYER ? Success() : Failure(:too_many_sets)
    end
  end
end
