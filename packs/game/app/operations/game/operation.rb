module Game
  # Base class of every Game operation (AD-14): each one acts for a player.
  # Defining `call` without a required `player:` keyword raises ArgumentError
  # when the class is loaded, and `require_player` refuses a missing, unsaved,
  # banned or deleted player. An operation that writes a player's bank takes
  # the bank lock through `lock_bank`, which refuses a player whose account
  # was deleted while it waited (Accounts::DeletePlayer).
  #
  #   class Game::OpenPack < Game::Operation
  #     def call(player:)
  #       player = step require_player(player)
  #       transaction { ... }
  #     end
  #   end
  class Operation < ApplicationOperation
    def self.method_added(name)
      if name == :call && self != Game::Operation
        # The class's own `call`, not dry-operation's prepended wrapper
        # (*args, **kwargs) that a redefinition would otherwise resolve to.
        method = instance_method(:call)
        method = method.super_method while method && method.owner != self
        unless method&.parameters&.include?([ :keyreq, :player ])
          raise ArgumentError, "#{self.name || "A Game operation"}#call must take a required player: keyword (AD-14)"
        end
      end

      super
    end

    # The event stream of a player's game (AD-10).
    def self.stream_name(player_id)
      "Game::Player$#{player_id}"
    end

    private

    def stream_name(player_id)
      Operation.stream_name(player_id)
    end

    # One Game::SetCompleted per set the player completed for the first time
    # (Game::SetCompletion's answer), on their stream (AD-10), after the
    # operation's own event.
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
