module Market
  class CancellationsController < ApplicationController
    LANDING = /\A[A-Za-z0-9_-]{0,64}\z/

    throttle_player to: 20, only: :create, path: -> { market_my_sales_path }, alert: "market.cancellations.create.throttled"

    def create
      token = params[:token].to_s
      listing_id = Game::Market::ListingIdByToken.call(token) || raise(ActiveRecord::RecordNotFound)
      authorize Game::Market::ListingByToken.call(token, locale: I18n.locale) || raise(ActiveRecord::RecordNotFound), :create?, policy_class: CancellationPolicy
      operation = Game::Market::CancelListing
      result = operation.new.call(player: current_player, listing_id:)
      if result.success?
        redirect_to destination(token, landing: true), notice: t(".cancelled"), status: :see_other
      else
        redirect_refused(operation, result, destination(token, landing: false))
      end
    end

    private
      def destination(token, landing:)
        return market_listing_path(token:) if params[:return_to].to_s == "annonce"
        return market_my_sales_path unless landing && params[:landing].to_s.match?(LANDING)

        market_my_sales_path(landing: params[:landing].to_s)
      end
  end
end
