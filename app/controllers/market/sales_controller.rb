module Market
  class SalesController < ApplicationController
    include PublicRead
    include CopyGrid

    throttle_player to: 10, only: :create, path: -> { new_market_sale_path }, alert: "market.sales.create.throttled"

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
      return redirect_to market_listing_path(token: result.value!.token), status: :see_other if result&.success?

      refuse_sale(result ? result.failure : :copy_not_free)
    end

    private
      def load_page(card_slug: nil)
        @settings = Game::Market::CurrentSettings.call
        @open = @settings&.open.present?
        @suspended = Game::Market::MarketState.call(@settings).suspended?
        @card_slug = card_slug
        @filter = copy_filter(doubles_by_default: false)
        load_grid
        choose(@copies.first.ref) if @pagy.count == 1 && !@filter.narrowing?
        @available = listed? ? Game::Market::Balance.call(current_player).available : 0
        @values = { start: "", duration: @settings&.preselected_duration_hours.to_s }
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
        return false unless copy

        @chosen_ref = ref
        @chosen_copy = copy
        @prices = @prices.merge(sale_prices([ ref ])) unless @prices.key?(ref)
        true
      end

      def sale_prices(refs)
        return {} unless @price_offered && refs.any?

        ids = Game::Market::EntrustableCopies.resolve(refs)
        prices = Game::Market::EditionPrices.call(ids.values, state: Game::Market::MarketState.call(@settings))
        ids.transform_values { prices[it] }
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
        @refusal = Game::Market::ListCard.failure_message(code, **refusal_values(code))
        @signed_out = code == :player_required
        render :new, status: @signed_out ? :unauthorized : :unprocessable_content
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
