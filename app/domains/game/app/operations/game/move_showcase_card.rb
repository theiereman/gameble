module Game
  # Moves one showcased card one place earlier or later, swapping it with
  # its neighbour in the showcase's order.
  class MoveShowcaseCard < Operation
    include ShowcaseSteps

    DIRECTIONS = { earlier: -1, later: 1 }.freeze

    def call(player:, card_season_id:, direction:)
      player = step require_player(player)
      step_by = step known_direction(direction)

      transaction do
        step lock_bank(player)
        entries = locked_entries(player)
        index = step showcased(entries, card_season_id)
        step within_showcase(entries, index + step_by)
        entries[index], entries[index + step_by] = entries[index + step_by], entries[index]
        place(entries)
        step moved(player, card_season_id, index + step_by)
      end
    end

    private

    def known_direction(direction)
      step_by = DIRECTIONS[direction.to_s.to_sym] if direction.is_a?(String) || direction.is_a?(Symbol)
      step_by ? Success(step_by) : Failure(:unknown_direction)
    end

    def within_showcase(entries, index)
      index.between?(0, entries.size - 1) ? Success() : Failure(:showcase_edge)
    end
  end
end
