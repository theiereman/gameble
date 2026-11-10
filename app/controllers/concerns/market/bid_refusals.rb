module Market
  # The answers of the bids endpoint: one Turbo Stream replacing the form region, drawn from the same readers as the Annonce.
  module BidRefusals
    extend ActiveSupport::Concern

    ENDED = %i[auction_ended listing_withdrawn].freeze

    private
      def token = params[:token].to_s

      def answer_refusal(code, status:)
        fresh = region
        answer_with(ENDED.include?(code) && fresh[:outcome] ? fresh.merge(not_recorded: true, focus: "heading") : with_refusal(fresh, code), status:)
      end

      def with_refusal(fresh, code)
        text = helpers.bid_refusal_text(code, sheet: fresh[:sheet], drawn_minimum: params[:drawn_minimum].to_s)
        fresh.merge(refusal: text, focus: "field")
      end

      def answer_with(region, status:)
        @region = region
        respond_to do |format|
          format.turbo_stream { render :create, status: }
          format.html { redirect_to market_listing_path(token:), status: :see_other }
        end
      end

      def region(answer: nil, focus: nil)
        detail = Game::Market::ListingByToken.call(token, locale: I18n.locale) || raise(ActiveRecord::RecordNotFound)
        { listing: detail, sheet: Game::Market::BidSheet.call(token:, player: current_player), viewer: current_player,
          outcome: Game::Market::ListingOutcome.call(token:, viewer: current_player, locale: I18n.locale),
          answer:, focus:, refusal: nil, not_recorded: false, posted: answer ? "" : params[:maximum].to_s,
          posted_amount: Integer(params[:maximum].to_s.strip, 10, exception: false) }
      end
  end
end
