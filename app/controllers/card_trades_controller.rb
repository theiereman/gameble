class CardTradesController < ApplicationController
  include CardDetailLoading
  include TradeProposals

  throttle_player to: 20, only: :create, path: -> { card_season_path(slug: params[:slug], number: params[:number]) }, alert: "trades.throttled"

  def create
    authorize :card_trade, :create?
    load_card_detail
    friend = befriended(params[:friend])
    refusal = friend ? helpers.trades_refusal(friend) : :not_friends
    return send_back(refusal, friend) if refusal

    holder = holder_among(friend)
    return send_back(:requested_cards_unavailable, friend) if holder.nil?
    return send_back(:trade_already_sent, friend) if holder.asked

    result = Game::ProposeTrade.new.call(player: current_player, recipient: friend, offer: {}, request: { holder.card_season_id => 1 })
    if result.success?
      toast_sent(friend, {})
      redirect_to trade_path(token: result.value!.token), status: :see_other
    else
      send_back(result.failure, friend)
    end
  end

  private
    def holder_among(friend)
      Game::FriendsHolding.call(current_player, card_id: @detail.card_id, card_season_id: @detail.card_season_id)
        .find { it.player.id == friend.id }
    end

    def send_back(code, friend)
      refused(code, friend)
      flash.delete(:trade_error)
      redirect_to card_season_path(slug: params[:slug], number: params[:number]), status: :see_other
    end
end
