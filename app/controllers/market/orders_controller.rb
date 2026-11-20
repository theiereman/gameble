module Market
  class OrdersController < ApplicationController
    throttle_player to: 10, only: :create, path: -> { new_market_card_order_path(slug: params[:slug].to_s) }, alert: "market.orders.create.throttled"

    def new
      authorize %i[market order], :new?
      load_card
      load_terms
      @price_text = ""
    end

    def create
      authorize %i[market order], :create?
      load_card
      operation = Game::Market::PlaceOrder
      result = operation.new.call(player: current_player, card_id: @detail.card_id, price: params[:price], settings_token: params[:settings_token].to_s)
      if result.success?
        flash[:placed_order] = result.value!.token
        return redirect_to market_my_orders_path, status: :see_other
      end

      load_terms
      @price_text = params[:price].to_s
      @refusal = operation.failure_message(result.failure, **refusal_values(result.failure))
      render :new, status: :unprocessable_content
    end

    private
      def load_card
        @detail = Catalog::CardDetail.call(slug: params[:slug].to_s, locale: I18n.locale) || raise(ActiveRecord::RecordNotFound)
      end

      def load_terms
        @settings = Game::Market::CurrentSettings.call || raise(ActiveRecord::RecordNotFound)
        @suspended = Game::Market::MarketState.call(@settings).suspended?
        @minimums = Game::Market::SettingsRules::RARITIES.index_with { @settings.minimum_price(it) }
        @available = Game::Market::Balance.call(current_player).available
      end

      def refusal_values(code)
        case code
        when :more_than_available then { amount: helpers.picoins(@available) }
        when :order_below_minimum
          lowest, amount = @minimums.min_by(&:last)
          { amount: helpers.picoins(amount), rarity: CardStrings.new.rarity_name(lowest) }
        when :order_already_open then running_order_values
        else {}
        end
      end

      def running_order_values
        order = Game::Market::PlayerOrders.open_on(current_player, @detail.card_id)
        days = order ? [ ((order.expires_at - Time.current) / 1.day).ceil, 0 ].max : 0
        { card: @detail.view.title, amount: helpers.picoins(order&.price || 0), days: }
      end
  end
end
