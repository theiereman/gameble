# Leader state for the tests that close auctions, until bidding exists.
#
#   fund!(player, 50_000)
#   lead!(listing, player, 40_000, price: 31_500)   # holds the maximum and sets the leader columns
module MarketAuctions
  def fund!(player, amount, settings: Game::Market::CurrentSettings.call)
    Game::Market::Mint.credit(player_id: player.id, amount:, settings_id: settings.id)
  end

  def lead!(listing, player, maximum, price: listing.current_price)
    Game::Market::Ledger.post(Game::Market::Ledger::Entry.new(player_id: player.id, kind: :hold, available_delta: -maximum, committed_delta: maximum,
      listing_id: listing.id, settings_id: listing.settings_id))
    listing.update!(leader_id: player.id, leader_maximum: maximum, current_price: price)
  end
end
