module Game
  class Operation < ApplicationOperation
    def self.method_added(name)
      if name == :call && self != Game::Operation
        # The class's own `call`, not dry-operation's prepended wrapper
        # (*args, **kwargs) that a redefinition would otherwise resolve to.
        method = instance_method(:call)
        method = method.super_method while method && method.owner != self
        unless method&.parameters&.include?([ :keyreq, :player ])
          raise ArgumentError, "#{self.name || "A Game operation"}#call must take a required player: keyword"
        end
      end

      super
    end

    def self.stream_name(player_id)
      "Game::Player$#{player_id}"
    end

    private

    def stream_name(player_id)
      Operation.stream_name(player_id)
    end

    def publish_completions(player_id, set_ids)
      set_ids.each do |set_id|
        publish(SetCompleted.new(data: { player_id:, set_id: }), stream_name: stream_name(player_id))
      end
      Success()
    end

    def require_player(player)
      if player.is_a?(Accounts::Player) && player.persisted? && !player.banned? && !player.deleted?
        Success(player)
      else
        Failure(:player_required)
      end
    end

    def require_account(player)
      player.is_a?(Accounts::Player) && player.persisted? ? Success(player) : Failure(:player_required)
    end

    # Takes the player's bank lock (Game::BankLock; inside `transaction`),
    # then reads afresh whether the account was deleted meanwhile: a deletion
    # releases the bank under the same lock (Game::ReleasePlayer), so an
    # operation that waited on it writes nothing and fails with
    # :player_required, leaving no row behind.
    def lock_bank(player)
      BankLock.acquire(player.id)
      Accounts::Player.where(id: player.id).where.not(deleted_at: nil).exists? ? Failure(:player_required) : Success()
    end
  end
end
