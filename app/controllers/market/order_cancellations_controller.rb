module Market
  class OrderCancellationsController < ApplicationController
    throttle_player to: 20, only: :create, path: -> { market_my_orders_path }, alert: "market.order_cancellations.create.throttled"

    def create
      authorize %i[market order_cancellation], :create?
      order_id = Game::Market::OrderIdByToken.call(params[:token]) || raise(ActiveRecord::RecordNotFound)
      operation = Game::Market::CancelOrder
      result = operation.new.call(player: current_player, order_id:)
      if result.success?
        redirect_to market_my_orders_path, notice: t(".cancelled", amount: helpers.picoins(result.value!.price)), status: :see_other
      else
        redirect_refused(operation, result, market_my_orders_path)
      end
    end
  end
end
