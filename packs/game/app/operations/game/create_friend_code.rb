module Game
  class CreateFriendCode < Operation
    ATTEMPTS = 10

    def call(player:)
      player = step require_account(player)
      ATTEMPTS.times do
        found = FriendCode.find_by(player_id: player.id)
        return found if found

        # Postgres aborts the caller's transaction on a unique violation outside a savepoint.
        FriendCode.transaction(requires_new: true) do
          FriendCode.insert({ player_id: player.id, code: FriendCode.random_code }, unique_by: :player_id)
        end
      rescue ActiveRecord::RecordNotUnique
        next
      end
      found = FriendCode.find_by(player_id: player.id)
      found || raise("no free friend code after #{ATTEMPTS} draws")
    end
  end
end
