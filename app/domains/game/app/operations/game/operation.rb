module Game
  class Operation < ApplicationOperation
    def self.method_added(name)
      if name == :call && self != Game::Operation
        # dry-operation prepends a (*args, **kwargs) wrapper that a redefinition would otherwise resolve to.
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

    def publish_tiers(player_id, reached)
      reached.each do |set_id, tier|
        event = tier == "complete" ? SetCompleted.new(data: { player_id:, set_id: }) : SetTierReached.new(data: { player_id:, set_id:, tier: })
        publish(event, stream_name: stream_name(player_id))
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

    def lock_bank(player)
      BankLock.acquire(player.id)
      Accounts::Player.where(id: player.id).where.not(deleted_at: nil).exists? ? Failure(:player_required) : Success()
    end
  end
end
