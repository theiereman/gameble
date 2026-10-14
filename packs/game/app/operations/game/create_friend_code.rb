module Game
  class CreateFriendCode < Operation
    ATTEMPTS = 10

    def call(player:)
      player = step require_account(player)

      transaction do
        step lock_bank(player)
        found = FriendCode.find_by(player_id: player.id)

        unless found
          ATTEMPTS.times do
            # Postgres aborts the caller's transaction on a unique violation outside a savepoint.
            FriendCode.transaction(requires_new: true) do
              FriendCode.insert({ player_id: player.id, code: FriendCode.random_code }, unique_by: :player_id)
            end
            found = FriendCode.find_by(player_id: player.id)
            break if found
          rescue ActiveRecord::RecordNotUnique
            next
          end
        end

        found || raise("no free friend code after #{ATTEMPTS} draws")
      end
    end
  end
end
