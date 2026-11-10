require_relative "market_sales"

module AltSignalSeeds
  include MarketSales

  def open_capsules!(player, count, on:)
    opened_at = on.in_time_zone("UTC") + 9.hours
    rows = Array.new(count) do
      Game::Pack.row(player_id: player.id, kind: :regular, season_id: catalog_seasons(:one).id,
        card_season_ids: Array.new(Game::Pack::SIZE, catalog_card_seasons(:portal_one).id), available_at: opened_at).merge(opened_at:)
    end
    Game::Pack.insert_all!(rows)
  end

  def trade!(proposer, recipient, offered:, requested:, closed_at: 1.day.ago, status: "accepted")
    low, high = [ proposer.id, recipient.id ].minmax
    trade = Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: proposer.id, recipient_id: recipient.id, status:,
      proposed_at: closed_at - 1.hour, expires_at: closed_at + 6.days, closed_at:)
    Game::TradeItem.create!(trade_id: trade.id, side: "offer", card_season_id: catalog_card_seasons(:common_card_one).id, quantity: offered)
    Game::TradeItem.create!(trade_id: trade.id, side: "request", card_season_id: catalog_card_seasons(:uncommon_card_one).id, quantity: requested)
    trade
  end

  def one_way_trade!(giver, receiver, closed_at: 1.day.ago) = trade!(giver, receiver, offered: 4, requested: 1, closed_at:)

  def sale!(seller, buyer, card_season, price, sold_at: 1.day.ago, average_after_sale: nil, settings: Game::Market::CurrentSettings.call)
    sold!(card_season, price, sold_at:, seller:, buyer:, average_after_sale:, settings:)
  end

  def priced_history!(card_season, average:, sales: Game::Market::EditionPrice::MINIMUM_SALES)
    sales.times { |ago| sale!(accounts_players(:administrator), accounts_players(:banned), card_season, average, sold_at: (60 + ago).days.ago, average_after_sale: average) }
  end

  def bid!(bidder, listing, outcome: "leading", created_at: 1.day.ago)
    Game::Market::Bid.create!(listing:, player: bidder, maximum: listing.current_price + 100, price_after: listing.current_price, outcome:, created_at:)
  end
end
