module Market
  class SalesController < ApplicationController
    include PublicRead
    include CopyGrid
    include DeckHoldingLoading

    throttle_player to: 10, only: %i[create sell], path: -> { new_market_sale_path }, alert: "market.sales.create.throttled"

    def new
      authorize %i[market sale], :new?
      load_page(card_slug: asked_card_slug(params[:slug]))
      prefill
      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def create
      authorize %i[market sale], :create?
      card_season_id = Game::Market::EntrustableCopies.resolve([ posted_ref ])[posted_ref]
      result = card_season_id && list(card_season_id)
      if result&.success?
        return head(:created) if request.format.json?

        return redirect_to market_listing_path(token: result.value!.token), status: :see_other
      end

      refuse_sale(result ? result.failure : :copy_not_free)
    end

    def sell
      authorize %i[market sale], :sell?
      card_season_id = Game::Market::EntrustableCopies.resolve([ posted_ref ])[posted_ref]
      result = card_season_id && Game::Market::SellToOrder.new.call(player: current_player, card_season_id:, order_token: params[:order].to_s,
        settings_token: params[:settings].to_s)
      return sold_to_order(result.value!, card_season_id) if result&.success?

      refuse_sale(result ? result.failure : :copy_not_free)
    end

    private
      def load_page(card_slug: nil)
        @settings = Game::Market::CurrentSettings.call
        @open = @settings&.open.present?
        @suspended = Game::Market::MarketState.call(@settings).suspended?
        @card_slug = card_slug
        @wanted = Game::Market::WantedCopies.call(current_player).index_by(&:ref)
        @filter = copy_filter(doubles_by_default: false, wanted_ids: @wanted.values.map(&:card_season_id))
        load_grid
        load_deck_holding
        choose(@copies.first.ref) if @pagy.count == 1 && !@filter.narrowing?
        @available = listed? ? Game::Market::Balance.call(current_player).available : 0
        @values = { start: "", duration: @settings&.preselected_duration_hours.to_s }
        @sold_to_order = flash[:sold_to_order]
      end

      def load_grid
        count = listed? ? Game::Market::SellableCopies.count(current_player, card_slug: @card_slug, filter: @filter) : 0
        @grid_path = @card_slug ? new_market_card_sale_path(slug: @card_slug) : new_market_sale_path
        @pagy = copy_pages(count, path: @grid_path, filter: @filter)
        @copies = count.positive? ? Game::Market::SellableCopies.call(current_player, card_slug: @card_slug, filter: @filter, offset: @pagy.offset, limit: @pagy.limit) : []
        @holds_copies = count.positive? || (listed? && @filter.narrowing? && Game::Market::SellableCopies.count(current_player, card_slug: @card_slug).positive?)
        @card_title = card_title if @card_slug
        @price_offered = Game::Market::MarketState.call(@settings).first_opened?
        @prices = sale_prices(@copies.map(&:ref))
        @orders = best_orders(@copies.map(&:ref))
      end

      def listed? = current_player.present? && @settings.present?

      def card_title
        any = @copies.first || Game::Market::SellableCopies.call(current_player, card_slug: @card_slug, limit: 1).first
        any&.card&.title
      end

      # The chosen edition stays chosen when its cell is on no loaded page: the fields and the summary still draw it.
      def choose(ref)
        return false if ref.blank?

        copy = @copies.find { it.ref == ref } || (Game::Market::SellableCopies.call(current_player, card_slug: @card_slug, refs: [ ref ]).first if listed?)
        return false unless copy&.free&.positive?

        @chosen_ref = ref
        @chosen_copy = copy
        @prices = @prices.merge(sale_prices([ ref ])) unless @prices.key?(ref)
        @orders = @orders.merge(best_orders([ ref ])) unless @orders.key?(ref)
        true
      end

      def sale_prices(refs)
        return {} unless @price_offered && refs.any?

        ids = Game::Market::EntrustableCopies.resolve(refs)
        prices = Game::Market::EditionPrices.call(ids.values, state: Game::Market::MarketState.call(@settings))
        ids.transform_values { prices[it] }
      end

      # The best order each edition can serve, by ref; only while the market is open.
      def best_orders(refs)
        return {} unless @open && current_player && refs.any?

        ids = Game::Market::EntrustableCopies.resolve(refs)
        best = Game::Market::EligibleOrders.best(ids.values, except: current_player.id)
        ids.transform_values { best[it] }.compact
      end

      def sold_to_order(order, card_season_id)
        amounts = helpers.order_sale_amounts(order.price, Game::Market::FindSettings.call(params[:settings]))
        flash[:sold_to_order] = { "card" => Game::Market::CardNames.call([ card_season_id ])[card_season_id].title, "received" => amounts[:received] }
        redirect_to(params[:card].present? ? new_market_card_sale_path(slug: params[:card].to_s) : new_market_sale_path, status: :see_other)
      end

      def asked_card_slug(slug)
        return if slug.nil?

        raise ActiveRecord::RecordNotFound unless Catalog::CardSlugKnown.call(slug)

        slug
      end

      def prefill
        return unless choose(params[:ref].to_s)

        @values[:start] = Game::Market::TypedAmount.price(params[:start]).to_s
        @relisting = params[:relisting].to_s == "1"
      end

      def posted_ref = params[:ref].to_s

      def list(card_season_id)
        Game::Market::ListCard.new.call(player: current_player, card_season_id:, starting_price: params[:starting_price],
          duration_hours: params[:duration_hours], settings_token: params[:settings].to_s)
      end

      def refuse_sale(code)
        load_page(card_slug: asked_card_slug(params[:card].presence))
        @refusal_code = code
        keep_posted_values
        @refusal_slot = helpers.sale_refusal_slot(code, invalid_price_at: invalid_price_field)
        @refusal_slot = :form if @refusal_slot == :order && !(@open && @chosen_copy)
        @refusal = refusal_message(code)
        @signed_out = code == :player_required
        status = @signed_out ? :unauthorized : :unprocessable_content
        return render(json: { error: { message: @refusal } }, status:) if request.format.json?

        render :new, status:
      end

      def keep_posted_values
        choose(posted_ref)
        @values[:start] = params[:starting_price].to_s
        duration = params[:duration_hours].to_s
        if allowed_durations.include?(duration)
          @values[:duration] = duration
        elsif @refusal_code == :invalid_duration
          @values[:duration] = ""
        end
      end

      def allowed_durations
        return [] unless @settings

        [ @settings.duration_short_hours, @settings.duration_medium_hours, @settings.duration_long_hours ].map(&:to_s)
      end

      def invalid_price_field
        :starting_price unless Game::Market::TypedAmount.price(params[:starting_price])
      end

      def refusal_message(code)
        return Game::Market::ListCard.failure_message(code, **refusal_values(code)) unless code == :best_order_changed && outbid?

        t("market.sales.order.better", amount: helpers.picoins_label(@orders.fetch(@chosen_ref).price))
      end

      # The posted order still stands but another now comes first.
      def outbid?
        card_season_id = Game::Market::EntrustableCopies.resolve([ posted_ref ])[posted_ref]
        @orders.key?(@chosen_ref) && card_season_id.present? &&
          Game::Market::EligibleOrders.call(card_season_id, except: current_player.id).exists?(token: params[:order].to_s)
      end

      def refusal_values(code)
        rarity = @chosen_copy&.card&.rarity&.to_sym
        return {} unless @settings && rarity

        case code
        when :start_below_minimum
          { amount: helpers.picoins(@settings.minimum_price(rarity)), rarity: helpers.sale_rarity_name(rarity) }
        when :stamp_not_covered
          shortfall = @settings.stamp(rarity) - Game::Market::Balance.call(current_player).available
          { amount: helpers.picoins([ shortfall, 1 ].max) }
        else
          {}
        end
      end
  end
end
