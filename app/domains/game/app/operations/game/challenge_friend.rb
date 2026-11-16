module Game
  class ChallengeFriend < Operation
    include DuelSteps

    def call(player:, friend:, deck_token:)
      player = step require_player(player)
      step other_player(player, friend)

      transaction do
        TradeLocks.players(player.id, friend.id)
        step friends_to_duel(player, friend.id)
        step reachable(player, friend)
        step idle(player)
        step free(friend)
        step ready_deck(player.id, deck_token)
        duel = Duel.create!
        seats = {
          challenger: DuelSeat.create!(duel_id: duel.id, role: "challenger", player_id: player.id, deck_token:, status: "seated"),
          opponent: DuelSeat.create!(duel_id: duel.id, role: "opponent", player_id: friend.id, status: "invited")
        }
        step duel_published(DuelChallengeSent, player, duel, seats)
        duel
      end
    end
  end
end
