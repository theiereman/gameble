module Game
  class RecordReveal < Operation
    def call(player:, token:, mode:)
      player = step require_player(player)
      mode = step known_mode(mode)

      transaction do
        step lock_bank(player)
        pack = step opened_pack(player, token)
        step latest(player, pack)
        next pack if pack.reveal_mode

        pack.update!(reveal_mode: mode)
        step publish(PackRevealed.new(data: { player_id: player.id, pack_id: pack.id, mode: }), stream_name: stream_name(player.id))
        pack
      end
    end

    private

    def known_mode(mode)
      mode.is_a?(String) && Pack::REVEAL_MODES.include?(mode) ? Success(mode) : Failure(:invalid_reveal_mode)
    end

    def opened_pack(player, token)
      pack = OpenedPackByToken.call(player, token)
      pack ? Success(pack) : Failure(:pack_not_found)
    end

    def latest(player, pack)
      Pack.where(player_id: player.id).latest_opened.pick(:id) == pack.id ? Success() : Failure(:not_latest_pack)
    end
  end
end
