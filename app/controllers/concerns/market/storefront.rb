module Market
  # What the market screen and the shop share: the page bounds, who may buy, and the cards the player wants.
  module Storefront
    extend ActiveSupport::Concern

    MAX_PAGE = 100_000

    private
      def asked_page = params[:page].to_s.to_i.clamp(1, MAX_PAGE)

      def buyable?(state) = current_player.present? && state.open?

      def wanted_card_ids
        @wanted_card_ids ||= Game::Market::WantedCardIds.call(current_player)
      end
  end
end
