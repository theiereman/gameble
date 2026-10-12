# Concludes a trade through the real operations: the two players become
# friends if they are not, each is given the copies their side gives, the
# proposer proposes and the recipient accepts.
module GameTrades
  def conclude_trade(proposer, recipient, offer:, request:)
    low, high = [ proposer.id, recipient.id ].minmax
    Game::Friendship.find_or_create_by!(low_player_id: low, high_player_id: high)
    { proposer => offer, recipient => request }.each do |player, cards|
      cards.each do |card_season_id, quantity|
        holding = Game::Holding.find_or_initialize_by(player_id: player.id, card_season_id:)
        holding.update!(quantity: holding.quantity.to_i + quantity)
      end
    end
    trade = Game::ProposeTrade.new.call(player: proposer, recipient:, offer:, request:).value!
    Game::AcceptTrade.new.call(player: recipient, trade_id: trade.id, revision: Game::Trade.find(trade.id).revision).value!
  end
end
