module Market
  class SalesController < ApplicationController
    include PublicRead

    PLAIN_AMOUNT = /\A\d{1,19}\z/

    throttle_player to: 10, only: :create, path: -> { new_market_sale_path }, alert: "market.sales.create.throttled"

    def new
      authorize %i[market sale], :new?
      load_page(card_slug: asked_card_slug(params[:slug]))
      prefill
    end

    def create
      authorize %i[market sale], :create?
      card_season_id = Game::Market::EntrustableCopies.resolve([ posted_ref ])[posted_ref]
      result = card_season_id && list(card_season_id)
      return redirect_to market_listing_path(token: result.value!.token), status: :see_other if result&.success?

      refuse(result ? result.failure : :copy_not_free)
    end

    private
      def load_page(card_slug: nil)
        @settings = Game::Market::CurrentSettings.call
        @open = @settings&.open.present?
        @suspended = Game::Market::MarketState.call(@settings).suspended?
        @card_slug = card_slug
        @copies = current_player && @settings ? Game::Market::SellableCopies.call(current_player, card_slug:) : []
        @chosen_ref = @copies.first.ref if @copies.one?
        @prices = sale_prices
        @values = { start: "", buy_now: "", duration: @settings&.preselected_duration_hours.to_s }
      end

      def sale_prices
        market = Game::Market::MarketState.call(@settings)
        return {} unless market.first_opened? && @copies.any?

        ids = Game::Market::EntrustableCopies.resolve(@copies.map(&:ref))
        prices = Game::Market::EditionPrices.call(ids.values, state: market)
        ids.transform_values { prices[it] }
      end

      def asked_card_slug(slug)
        return if slug.nil?

        raise ActiveRecord::RecordNotFound unless Catalog::CardSlugKnown.call(slug)

        slug
      end

      def prefill
        ref = params[:ref].to_s
        return unless @copies.any? { it.ref == ref }

        @chosen_ref = ref
        @values[:start] = plain_digits(params[:start])
        @values[:buy_now] = plain_digits(params[:buy_now])
        @relisting = params[:relisting].to_s == "1"
      end

      def plain_digits(value) = PLAIN_AMOUNT.match?(value.to_s) ? value.to_s : ""

      def posted_ref = params[:ref].to_s

      def list(card_season_id)
        Game::Market::ListCard.new.call(player: current_player, card_season_id:, starting_price: params[:starting_price],
          buy_now_price: params[:buy_now_price], duration_hours: params[:duration_hours], settings_token: params[:settings].to_s)
      end

      def refuse(code)
        load_page(card_slug: asked_card_slug(params[:card].presence))
        @refusal_code = code
        keep_posted_values
        @refusal_slot = helpers.sale_refusal_slot(code, invalid_price_at: invalid_price_field)
        @refusal = Game::Market::ListCard.failure_message(code, **refusal_values(code))
        @signed_out = code == :player_required
        render :new, status: @signed_out ? :unauthorized : :unprocessable_content
      end

      def keep_posted_values
        @chosen_ref = posted_ref if @copies.any? { it.ref == posted_ref }
        @values[:start] = params[:starting_price].to_s
        @values[:buy_now] = params[:buy_now_price].to_s
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
        plain = ->(value) { PLAIN_AMOUNT.match?(value.to_s) && value.to_i.between?(1, Game::Market::PriceAmount::MAX_AMOUNT) }
        return :starting_price unless plain.call(params[:starting_price])

        :buy_now_price unless params[:buy_now_price].to_s.strip.empty? || plain.call(params[:buy_now_price])
      end

      def refusal_values(code)
        rarity = @copies.find { it.ref == @chosen_ref }&.card&.rarity&.to_sym
        return {} unless @settings && rarity

        case code
        when :start_below_minimum, :buy_now_below_minimum
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
