module Game
  # Shifts one player's copies of the cards of a batch, in card-season order: `given` leaves, `gained` arrives, `released` frees reserved copies.
  module MoveHoldings
    private

    def move(player_id, holdings, given:, gained:, released:, now:)
      (given.keys | gained.keys).sort.each do |card_season_id|
        net = gained.fetch(card_season_id, 0) - given.fetch(card_season_id, 0)
        unreserve = released.fetch(card_season_id, 0)
        holding = holdings[card_season_id]
        if holding.nil?
          Holding.insert_all!([ { player_id:, card_season_id:, quantity: net, reserved: 0, last_gained_at: now, created_at: now, updated_at: now } ],
            record_timestamps: false)
        elsif net.positive?
          Holding.where(id: holding.id).update_all([ "quantity = quantity + ?, reserved = reserved - ?, last_gained_at = ?, updated_at = ?", net, unreserve, now, now ])
        else
          Holding.where(id: holding.id).update_all([ "quantity = quantity + ?, reserved = reserved - ?, updated_at = ?", net, unreserve, now ])
        end
      end
    end
  end
end
