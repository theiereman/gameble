# Gives a player copies of a card-season, straight into the holdings: the
# arrangement of the tests that read or trade what a player holds.
module Holdings
  # `gained_at`: when the copies were last gained (nil: before the tracking of
  # new cards, never new).
  def hold(player, card_season_id, quantity = 1, reserved: 0, gained_at: nil)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:, reserved:, last_gained_at: gained_at)
  end
end
