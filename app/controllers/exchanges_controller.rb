class ExchangesController < ApplicationController
  def show
    authorize :exchange, :show?
    redirect_to Game::ExchangesTab.call(current_player) == "market" ? market_path : trades_path
  end
end
