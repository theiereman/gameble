module Market
  class OrdersController < ApplicationController
    include GoalMarksLoading

    BACK_FROM = %w[my_orders card].freeze

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
      @refusal_code = result.failure
      @refusal = operation.failure_message(@refusal_code, **refusal_values(@refusal_code)) unless @refusal_code == :order_already_open
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
        @listings = Game::Market::CardListings.call(@detail.card_id, locale: I18n.locale)
        @archive_offers = @listings.empty? ? Game::Market::ArchiveOffers.for_card(settings: @settings, card_id: @detail.card_id, locale: I18n.locale) : []
        @buyable = @settings.open
        @best_order = Game::Market::BestVisibleOrder.call(@detail.card_id, viewer: current_player)
        @running = Game::Market::PlayerOrders.open_on(current_player, @detail.card_id)
        @goal = goal_marks.needs.find { it.missing_card_ids.include?(@detail.card_id) }
        @from = params[:from].presence_in(BACK_FROM)
      end

      def refusal_values(code)
        case code
        when :more_than_available then { amount: helpers.picoins(@available) }
        when :order_below_minimum
          lowest, amount = @minimums.min_by(&:last)
          { amount: helpers.picoins(amount), rarity: CardStrings.new.rarity_name(lowest) }
        else {}
        end
      end
  end
end
