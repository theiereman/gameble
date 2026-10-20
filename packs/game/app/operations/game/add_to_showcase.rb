module Game
  class AddToShowcase < Operation
    def call(player:, card_season_id:)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        step held(player, card_season_id)
        entries = ShowcaseEntry.where(player_id: player.id)
        step not_showcased(entries, card_season_id)
        step room_left(entries)
        ShowcaseEntry.create!(player_id: player.id, card_season_id:, position: next_position(entries))
        step publish(ShowcaseCardAdded.new(data: { player_id: player.id, card_season_id: }), stream_name: stream_name(player.id))
      end
    end

    private

    def held(player, card_season_id)
      holding = Holding.where(player_id: player.id, card_season_id:).lock.first
      holding&.quantity&.positive? ? Success() : Failure(:card_not_owned)
    end

    def not_showcased(entries, card_season_id)
      entries.exists?(card_season_id:) ? Failure(:card_already_showcased) : Success()
    end

    def room_left(entries)
      entries.count < ShowcaseEntry::SIZE ? Success() : Failure(:showcase_full)
    end

    def next_position(entries)
      (entries.maximum(:position) || -1) + 1
    end
  end
end
