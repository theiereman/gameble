module Game
  # Moves one showcased card one place earlier or later, swapping it with
  # its neighbour in the showcase's order (position, then id), and places
  # every card at 0..n-1, so a gap or a shared place heals on the move.
  # The rows are locked, so a trade's removal of a card waits for the move.
  class MoveShowcaseCard < Operation
    DIRECTIONS = { earlier: -1, later: 1 }.freeze

    def call(player:, card_season_id:, direction:)
      player = step require_player(player)
      step_by = step known_direction(direction)

      transaction do
        step lock_bank(player)
        entries = ShowcaseEntry.where(player_id: player.id).order(:position, :id).lock.to_a
        index = step showcased(entries, card_season_id)
        step within_showcase(entries, index + step_by)
        entries[index], entries[index + step_by] = entries[index + step_by], entries[index]
        place(entries)
        step publish(ShowcaseCardMoved.new(data: { player_id: player.id, card_season_id:, position: index + step_by }), stream_name: stream_name(player.id))
      end
    end

    private

    def known_direction(direction)
      step_by = DIRECTIONS[direction.to_s.to_sym] if direction.is_a?(String) || direction.is_a?(Symbol)
      step_by ? Success(step_by) : Failure(:unknown_direction)
    end

    def showcased(entries, card_season_id)
      index = entries.index { it.card_season_id == card_season_id }
      index ? Success(index) : Failure(:card_not_showcased)
    end

    def within_showcase(entries, index)
      index.between?(0, entries.size - 1) ? Success() : Failure(:showcase_edge)
    end

    def place(entries)
      now = Time.current
      entries.each_with_index do |entry, position|
        ShowcaseEntry.where(id: entry.id).update_all(position:, updated_at: now) unless entry.position == position
      end
    end
  end
end
