# Opened capsules and accepted trades straight into the tables, for the tests that read the alt-account signals.
#
#   open_capsules!(player, 130, on: Date.new(2026, 11, 3))
#   one_way_trade!(giver, receiver, closed_at: 2.days.ago)
module AltSignalSeeds
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
end
