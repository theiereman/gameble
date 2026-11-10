# Bids placed through the operation, and the figures they leave, for the tests of the auction rules.
#
#   bid(@bidder, 30_000)              # the listing under test, @listing
#   figures(@bidder)                  # [available, committed]
module MarketBidding
  def bid(player, maximum, listing = @listing) = Game::Market::PlaceBid.new.call(player:, listing_id: listing.id, maximum:)

  def wallet(player) = Game::Market::Wallet.find_by!(player_id: player.id)

  def figures(player) = wallet(player).attributes.values_at("available", "committed")

  def entries_of(listing = @listing) = Game::Market::LedgerEntry.where(listing_id: listing.id).order(:id)

  def outcomes(player, listing = @listing) = Game::Market::Bid.where(listing_id: listing.id, player_id: player.id).order(:id).pluck(:outcome)

  def events(type) = Rails.configuration.event_store.read.of_type(type).to_a

  def nothing_changes(listing = @listing, &)
    before = listing.reload.attributes
    assert_no_difference([ -> { Game::Market::Bid.count }, -> { Game::Market::LedgerEntry.count }, -> { Rails.configuration.event_store.read.count } ], &)
    assert_equal before, listing.reload.attributes
  end
end
