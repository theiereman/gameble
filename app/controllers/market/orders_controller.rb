module Market
  class OrdersController < ApplicationController
    include GoalMarksLoading

    BACK_FROM = %w[my_orders card].freeze

    throttle_player to: 10, only: %i[create update], alert: "market.orders.create.throttled", path: -> { order_screen_path }

    def new
      authorize %i[market order], :new?
      load_card
      load_terms
    end

    def create
      authorize %i[market order], :create?
      load_card
      operation = Game::Market::PlaceOrder
      result = operation.new.call(player: current_player, card_id: @detail.card_id, price: params[:price], settings_token: params[:settings_token].to_s)
      return answer_placed(result.value!) if result.success?

      redraw_refused(operation, result.failure)
    end

    def update
      authorize %i[market order], :update?
      load_card
      order_id = Game::Market::OrderIdByToken.on_card(params[:token], @detail.card_id) || raise(ActiveRecord::RecordNotFound)
      operation = Game::Market::RepriceOrder
      result = operation.new.call(player: current_player, order_id:, price: params[:price], settings_token: params[:settings_token].to_s)
      return redraw_refused(operation, result.failure) if result.failure?

      flash[:notice] = t(".repriced", card: @detail.view.title, amount: helpers.picoins(result.value!.price))
      redirect_to order_screen_path, status: :see_other
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
        @caps = Game::Market::ArchiveCaps.call(player: current_player, settings: @settings)
        @best_order = Game::Market::BestVisibleOrder.call(@detail.card_id, viewer: current_player)
        @running = Game::Market::PlayerOrders.open_on(current_player, @detail.card_id)
        @price_text = @running ? @running.price.to_s : ""
        @goal = goal_marks.needs.find { it.missing_card_ids.include?(@detail.card_id) }
        @from = params[:from].presence_in(BACK_FROM)
        @chain = chain_params
      end

      def order_screen_path
        new_market_card_order_path(slug: params[:slug].to_s, **%i[from goal of].index_with { params[it].to_s }.compact_blank)
      end

      def redraw_refused(operation, code)
        load_terms
        @price_text = params[:price].to_s
        @refusal_code = code == :order_already_open && @running.nil? ? :market_busy : code
        @refusal = operation.failure_message(@refusal_code, **refusal_values(@refusal_code))
        render :new, status: :unprocessable_content
      end

      def chain_params
        { goal: params[:goal].to_s, of: params[:of].to_s } if params[:goal].to_s.match?(/\A\d+\z/)
      end

      def chained_goal
        number = chain_params&.fetch(:goal)
        goal_marks.needs.find { it.position.to_s == number } if number
      end

      def answer_placed(order)
        goal = chained_goal
        return continue_chain(goal, order) if goal

        flash[:placed_order] = order.token
        redirect_to market_my_orders_path, status: :see_other
      end

      def continue_chain(goal, order)
        left = Game::Market::CardsToOrder.call(current_player, [ goal ], locale: I18n.locale).fetch(goal.goal_id, [])
        length = [ params[:of].to_s.to_i, left.size + 1 ].max
        line = t("market.orders.create.chain", card: @detail.view.title, amount: helpers.picoins(order.price), index: length - left.size, count: length)
        return redirect_to_next(goal, left.first, line, length) if left.any?

        flash[:notice] = line
        flash[:order_chain_ended] = true
        redirect_to helpers.goal_album_path(goal), status: :see_other
      end

      def redirect_to_next(goal, card, line, length)
        flash[:order_chain] = line
        redirect_to new_market_card_order_path(slug: card.id, goal: goal.position, of: length), status: :see_other
      end

      def refusal_values(code)
        case code
        when :more_than_available, :not_covered then { amount: helpers.picoins(@available) }
        when :order_already_open
          { card: @detail.view.title, amount: helpers.picoins(@running.price), days: [ ((@running.expires_at - Time.current) / 1.day).ceil, 0 ].max }
        when :order_below_minimum
          lowest, amount = @minimums.min_by(&:last)
          { amount: helpers.picoins(amount), rarity: CardStrings.new.rarity_name(lowest) }
        else {}
        end
      end
  end
end
