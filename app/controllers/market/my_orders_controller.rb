module Market
  class MyOrdersController < ApplicationController
    include Market::DeskLoading

    def show
      authorize %i[market my_order], :show?
      @orders = Game::Market::PlayerOrders.call(player: current_player, locale: I18n.locale)
      @placed = @orders.in_progress.find { it.token == flash[:placed_order].to_s }
      @balance = Game::Market::Balance.call(current_player) if @placed
      @suspended = Game::Market::MarketState.call.suspended?
      load_desk
    end
  end
end
