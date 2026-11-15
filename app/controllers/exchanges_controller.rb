class ExchangesController < ApplicationController
  def show
    authorize :exchange, :show?
    redirect_to kept_tab == "market" ? market_path : trades_path
  end

  private
    def kept_tab
      current_player ? Game::ExchangesTab.call(current_player) : "market"
    end
end
