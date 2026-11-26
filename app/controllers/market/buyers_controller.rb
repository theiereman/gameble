module Market
  class BuyersController < ApplicationController
    include Market::DeskLoading

    KINDS = %w[all orders goals].freeze

    def show
      authorize %i[market buyer], :show?
      @suspended = Game::Market::MarketState.call.suspended?
      load_desk
      @kind = params[:kind].presence_in(KINDS) || "all"
      @rarities = Game::Market::SettingsRules::RARITIES.select { |rarity| @wanted_copies.any? { it.rarity == rarity } }
      @rarity = @rarities.find { it.to_s == params[:rarity] }
      @shown_copies = shown_copies
      @wanted_cards = Catalog::CardViews.call(@shown_copies.map(&:card_season_id), locale: I18n.locale)
      @held_copies = held_copies
    end

    private
      def shown_copies
        copies = @wanted_copies.select { |copy| @kind == "all" || (@kind == "orders") == copy.order.present? }
        copies = copies.select { it.rarity == @rarity } if @rarity
        copies.sort_by { [ it.order ? 0 : 1, -(it.order&.price || 0), -it.seekers, it.ref ] }
      end

      def held_copies
        season = Catalog::PublishedSeason.call
        return {} unless season

        Game::HeldGames.editions(current_player, card_ids: @wanted_cards.values.map(&:card_id), season:).transform_values(&:copies)
      end
  end
end
