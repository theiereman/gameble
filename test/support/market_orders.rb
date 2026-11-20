# Buy orders straight into the table, their price held as PlaceOrder holds it: the arrangement of the tests that serve orders.
#
#   order!(buyer, catalog_card_seasons(:rare_card_one), 900)   # an open order on the edition's card
#   buyer!                                                     # another player to place one
module MarketOrders
  def order!(player, card_season, price, settings: Game::Market::CurrentSettings.call, created_at: Time.current, expires_at: 7.days.from_now)
    order = Game::Market::Order.create!(player:, card_id: card_season.card_id, settings:, price:, created_at:, expires_at:)
    Game::Market::Ledger.post(Game::Market::Ledger::Entry.new(player_id: player.id, kind: :hold, available_delta: -price, committed_delta: price,
      order_id: order.id, settings_id: settings.id))
    order
  end

  def buyer! = Accounts::Player.create!
end
