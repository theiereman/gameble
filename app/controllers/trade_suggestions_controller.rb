class TradeSuggestionsController < ApplicationController
  include TradeProposals

  throttle_player to: 20, only: :create, path: -> { trades_path }, alert: "trades.throttled"

  def create
    authorize :trade_suggestion, :create?
    friend = befriended(params[:friend])
    refusal = friend ? helpers.trades_refusal(friend) : :not_friends
    return refuse_suggestion(refusal, friend) if refusal

    result = sent_sides(friend).bind { Game::ProposeTrade.new.call(player: current_player, recipient: friend, **it) }
    return refuse_suggestion(result.failure, friend) if result.failure?

    flash[:title_toast] = t("trades.suggestions.sent")
    flash[:sent_suggestion] = { "position" => sent_position, "trade" => result.value!.token }
    redirect_to trades_path, status: :see_other
  end

  private
    def sent_position = params[:position].to_i.clamp(0, Game::TradeSuggestions::MAX_SUGGESTIONS - 1)

    def refuse_suggestion(code, friend)
      refused(code, friend)
      flash.delete(:trade_error)
      redirect_to trades_path, status: :see_other
    end
end
