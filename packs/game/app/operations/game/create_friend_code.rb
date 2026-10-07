module Game
  # Gives a player their friend code (AD-8): a random XXXX-XXXX, unique. A
  # player who has one keeps it, so a rerun changes nothing. A collision with
  # another player's code (the unique index) draws another. Housekeeping: it
  # publishes no event (AD-10).
  #
  #   Game::CreateFriendCode.new.call(player:)
  #   # => friend_code | Failure(:player_required)
  class CreateFriendCode < Operation
    ATTEMPTS = 10

    def call(player:)
      player = step persisted_player(player)
      ATTEMPTS.times do
        found = FriendCode.find_by(player_id: player.id)
        return found if found

        # A savepoint, so a collision does not abort the caller's transaction.
        FriendCode.transaction(requires_new: true) do
          FriendCode.insert({ player_id: player.id, code: FriendCode.random_code }, unique_by: :player_id)
        end
      rescue ActiveRecord::RecordNotUnique
        next
      end
      found = FriendCode.find_by(player_id: player.id)
      found || raise("no free friend code after #{ATTEMPTS} draws")
    end

    private

    def persisted_player(player)
      player.is_a?(Accounts::Player) && player.persisted? ? Success(player) : Failure(:player_required)
    end
  end
end
