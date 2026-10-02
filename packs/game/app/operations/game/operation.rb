module Game
  # Base class of every Game operation (AD-14): each one acts for a player.
  # Defining `call` without a required `player:` keyword raises ArgumentError
  # when the class is loaded, and `require_player` refuses a missing, unsaved
  # or banned player.
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

    private

    def require_player(player)
      if player.is_a?(Accounts::Player) && player.persisted? && !player.banned?
        Success(player)
      else
        Failure(:player_required)
      end
    end
  end
end
