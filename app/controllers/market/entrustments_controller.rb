module Market
  class EntrustmentsController < ApplicationController
    include PublicRead
    include CopyGrid

    SELECTION_SEPARATOR = ",".freeze
    SELECTION_PAIR = /\A(?<ref>[^:,=\s]+:\d+)=(?<copies>\d+)\z/

    throttle_player to: 10, only: :create, path: -> { new_market_entrustment_path }, alert: "market.entrustments.create.throttled"

    def new
      authorize %i[market entrustment], :new?
      load_page(card_slug: asked_card_slug(params[:slug]))
      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    # Every edition the filter keeps, for a selection of all of them.
    def matching
      authorize %i[market entrustment], :matching?
      @settings = Game::Market::CurrentSettings.call
      @card_slug = asked_card_slug(params[:card])
      copies = listed? ? Game::Market::EntrustableCopies.call(current_player, settings: @settings, card_slug: @card_slug, filter: asked_filter, cards: false) : []
      render json: copies.map { { ref: it.ref, title: it.title, rarity: it.rarity, season: it.season_number, free: it.free, owned: it.owned, value: it.value } }
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
        @stayed_names = Game::Market::CardNames.call(entrusted.stayed.first(MarketEntrustmentsHelper::RESULT_LINES).map(&:card_season_id))
        load_page(card_slug: asked_card_slug(params[:card]), keep_ticks: false)
        redraw(status: :ok)
      end

      def show_refusal(code)
        @refusal = Game::Market::EntrustCards.failure_message(code)
        load_page(card_slug: asked_card_slug(params[:card]))
        redraw(status: :unprocessable_content)
      end

      def redraw(status:)
        respond_to do |format|
          format.turbo_stream { render :create, status: }
          format.html { render :new, status: }
        end
      end

      def load_page(card_slug: nil, keep_ticks: true)
        @settings = Game::Market::CurrentSettings.call
        @open = @settings&.open.present?
        @suspended = Game::Market::MarketState.call(@settings).suspended?
        @card_slug = card_slug
        @filter = asked_filter
        @cap_left = listed? ? Game::Market::CapLeft.call(current_player.id, settings: @settings) : 0
        load_grid
        @ticked_copies = keep_ticks ? ticked_copies : []
        @ticked_copies = [ [ @copies.first, 1 ] ] if lone_card_edition?
        @ticked = @ticked_copies.to_h { |copy, count| [ copy.ref, count ] }
      end

      # A card's page with a single free edition opens with it ticked.
      def lone_card_edition? = @card_slug.present? && ticked.empty? && @copies.one?

      def load_grid
        count = listed? ? Game::Market::EntrustableCopies.count(current_player, card_slug: @card_slug, filter: @filter) : 0
        @grid_path = @card_slug ? new_market_card_entrustment_path(slug: @card_slug) : new_market_entrustment_path
        @pagy = copy_pages(count, path: @grid_path, filter: @filter)
        @copies = count.positive? ? Game::Market::EntrustableCopies.call(current_player, settings: @settings, card_slug: @card_slug, filter: @filter,
          offset: @pagy.offset, limit: @pagy.limit) : []
        @holds_copies = count.positive? || (listed? && @filter.narrowing? && Game::Market::EntrustableCopies.count(current_player, card_slug: @card_slug).positive?)
        @card_title = card_title if @card_slug
      end

      def card_title
        any = @copies.first || Game::Market::EntrustableCopies.call(current_player, settings: @settings, card_slug: @card_slug, limit: 1, cards: false).first
        any&.title
      end

      def listed? = current_player.present? && @settings.present?

      def asked_filter = copy_filter(doubles_by_default: @card_slug.nil?)

      def asked_card_slug(slug)
        return if slug.nil?

        raise ActiveRecord::RecordNotFound unless Catalog::CardSlugKnown.call(slug)

        slug
      end

      # What was posted, kept to the copies still free, with what the recap needs to name them.
      def ticked_copies
        posted = ticked
        return [] if posted.empty? || !listed?

        Game::Market::EntrustableCopies.call(current_player, settings: @settings, card_slug: @card_slug, refs: posted.keys, cards: false).filter_map do |copy|
          count = [ Integer(posted[copy.ref], exception: false).to_i, copy.free ].min
          [ copy, count ] if count.positive?
        end
      end

      # The order of the copies' list; a ticked ref that is no longer a free copy goes last, for the operation to refuse.
      def most_valuable_first(resolved)
        settings = Game::Market::CurrentSettings.call
        copies = settings ? Game::Market::EntrustableCopies.call(current_player, settings:, refs: resolved.map(&:first), cards: false) : []
        position = copies.each_with_index.to_h { |copy, index| [ copy.ref, index ] }
        resolved.each_with_index
          .sort_by { |(ref, _, _), posted| [ position.fetch(ref, position.size), posted ] }
          .map { |(_, card_season_id, copies_count), _| [ card_season_id, copies_count ] }
      end

      # One field of "ref=copies" pairs: a field per tick would pass Rack's limit of 4,096 parameters.
      def ticked
        @posted_ticks ||= posted_selection.split(SELECTION_SEPARATOR).filter_map { SELECTION_PAIR.match(it)&.captures }.to_h
      end

      def posted_selection = params[:selection].is_a?(String) ? params[:selection] : ""
  end
end
