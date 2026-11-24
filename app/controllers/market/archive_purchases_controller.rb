module Market
  class ArchivePurchasesController < ApplicationController
    include GoalMarksLoading

    throttle_player to: 10, only: :create, alert: "market.archive_purchases.create.throttled",
      path: -> { new_market_archive_purchase_path(slug: params[:slug].to_s, number: params[:number].to_s) }

    def new
      authorize %i[market archive_purchase], :new?
      load_edition
      load_terms
      @refusal = flash[:alert] || standing_refusal
    end

    def create
      authorize %i[market archive_purchase], :create?
      load_edition
      result = Game::Market::BuyFromArchives.new.call(player: current_player, card_season_id: @card_season_id,
        purchase_token: params[:purchase_token].to_s, settings_token: params[:settings_token].to_s)
      @withdrawal = result.value! if result.success?
      load_terms
      @refusal = refusal(result.failure) if result.failure?
      @marks = ListingMarks.for(current_player, [ @offer ].compact, goal_marks, Game::Market::WantedCardIds.call(current_player))
      status = result.success? ? :ok : :unprocessable_content
      respond_to do |format|
        format.turbo_stream { render :create, status: }
        format.html { render :new, status: }
      end
    end

    private
      def load_edition
        ref = Game::Market::EntrustableCopies.ref(params[:slug].to_s, params[:number].to_s)
        @card_season_id = Game::Market::EntrustableCopies.resolve([ ref ])[ref] || raise(ActiveRecord::RecordNotFound)
        @card = Catalog::CardViews.call([ @card_season_id ], locale: I18n.locale)[@card_season_id] || raise(ActiveRecord::RecordNotFound)
      end

      def load_terms
        @settings = Game::Market::CurrentSettings.call || raise(ActiveRecord::RecordNotFound)
        @offer = Game::Market::ArchiveOffers.find(settings: @settings, card_season_id: @card_season_id, locale: I18n.locale)
        @available = Game::Market::Balance.call(current_player).available
        @caps = Game::Market::ArchiveCaps.call(player: current_player, settings: @settings)
        @purchase_token = SecureRandom.base58(24)
        @state = purchase_state
      end

      def purchase_state
        if @offer.nil? || !@settings.open then :closed
        elsif standing&.reached? then :capped
        elsif @available < @offer.price then :short
        else :buyable
        end
      end

      def standing = @offer && @caps[@offer.card.rarity.to_sym]

      def standing_refusal
        if !@settings.open then refusal(:market_closed)
        elsif @offer.nil? then refusal(:out_of_stock)
        elsif @state == :capped then refusal(:archive_cap_reached)
        end
      end

      def refusal(code)
        case code
        when :more_than_available then nil
        when :archive_cap_reached then operation.failure_message(code, date: helpers.archive_cap_date(standing))
        when :out_of_stock then [ operation.failure_message(code), t("market.archive_purchases.refusals.last_copy") ].join(" ")
        else operation.failure_message(code)
        end
      end

      def operation = Game::Market::BuyFromArchives
  end
end
