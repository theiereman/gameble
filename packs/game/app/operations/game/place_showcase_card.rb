module Game
  # Puts one showcased card at a given place (0 first), each card between
  # its old place and the new one shifting one place to make room: the
  # owner dropping a card where they dragged it on their profile.
  class PlaceShowcaseCard < Operation
    include ShowcaseSteps

    def call(player:, card_season_id:, position:)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        entries = locked_entries(player)
        index = step showcased(entries, card_season_id)
        step within_showcase(entries, position)
        entries.insert(position, entries.delete_at(index))
        place(entries)
        step moved(player, card_season_id, position)
      end
    end

    private

    def within_showcase(entries, position)
      position.is_a?(Integer) && position.between?(0, entries.size - 1) ? Success() : Failure(:position_out_of_range)
    end
  end
end
