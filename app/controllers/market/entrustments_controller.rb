module Market
  class EntrustmentsController < ApplicationController
    include PublicRead

    throttle_player to: 10, only: :create, path: -> { new_market_entrustment_path }, alert: "market.entrustments.create.throttled"

    def new
      authorize %i[market entrustment], :new?
      load_page(card_slug: asked_card_slug(params[:slug]))
    end

    def create
      authorize %i[market entrustment], :create?
      ids = Game::Market::EntrustableCopies.resolve(ticked.keys)
      lines = most_valuable_first(ticked.filter_map { |ref, copies| [ ref, ids[ref], copies ] if ids.key?(ref) })
      result = Game::Market::EntrustCards.new.call(player: current_player, lines:, settings_token: params[:settings].to_s)
      result.success? ? show_entrusted(result.value!) : show_refusal(result.failure)
    end

    private
      def show_entrusted(entrusted)
        @entrusted = entrusted
        @stayed_names = Game::Market::CardNames.call(entrusted.stayed.map(&:card_season_id))
        load_page(card_slug: asked_card_slug(params[:card]), filter: posted_filter)
        @ticked = {}
        redraw(status: :ok)
      end

      def show_refusal(code)
        @refusal = Game::Market::EntrustCards.failure_message(code)
        load_page(card_slug: asked_card_slug(params[:card]), filter: posted_filter)
        redraw(status: :unprocessable_content)
      end

      def redraw(status:)
        respond_to do |format|
          format.turbo_stream { render :create, status: }
          format.html { render :new, status: }
        end
      end

      def load_page(card_slug: nil, filter: nil)
        @settings = Game::Market::CurrentSettings.call
        @open = @settings&.open.present?
        @suspended = Game::Market::MarketState.call(@settings).suspended?
        @card_slug = card_slug
        @filter = filter || { query: "", rarities: [], doubles: card_slug.nil? }
        @copies = current_player && @settings ? Game::Market::EntrustableCopies.call(current_player, settings: @settings, card_slug:) : []
        @cap_left = current_player && @settings ? Game::Market::CapLeft.call(current_player.id, settings: @settings) : 0
        @ticked = ticked_on(@copies)
        @ticked = { @copies.first.ref => 1 } if card_slug && @ticked.empty? && ticked.empty? && @copies.one?
      end

      def asked_card_slug(slug)
        return if slug.nil?

        raise ActiveRecord::RecordNotFound unless Catalog::CardSlugKnown.call(slug)

        slug
      end

      # The filters the player had set, so a redrawn list keeps showing the same cards.
      def posted_filter
        posted = params[:filter]
        return unless posted.respond_to?(:to_unsafe_h)

        rarities = Array(posted[:rarities]).grep(String) & Catalog::Rarity::TIERS.values.map(&:to_s)
        { query: posted[:query].is_a?(String) ? posted[:query] : "", rarities:, doubles: posted[:doubles].present? }
      end

      # What was posted, kept to the copies still free on the redrawn list.
      def ticked_on(copies)
        posted = ticked
        copies.filter_map do |copy|
          count = [ Integer(posted[copy.ref], exception: false).to_i, copy.free ].min
          [ copy.ref, count ] if count.positive?
        end.to_h
      end

      # The order of the page's copies; a ticked ref that is no longer a free copy goes last, for the operation to refuse.
      def most_valuable_first(resolved)
        settings = Game::Market::CurrentSettings.call
        copies = settings ? Game::Market::EntrustableCopies.call(current_player, settings:) : []
        position = copies.each_with_index.to_h { |copy, index| [ copy.ref, index ] }
        resolved.each_with_index
          .sort_by { |(ref, _, _), posted| [ position.fetch(ref, position.size), posted ] }
          .map { |(_, card_season_id, copies_count), _| [ card_season_id, copies_count ] }
      end

      def ticked
        copies = params[:copies]
        copies.respond_to?(:to_unsafe_h) ? copies.to_unsafe_h.select { |ref, count| ref.is_a?(String) && count.is_a?(String) } : {}
      end
  end
end
