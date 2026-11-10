module Game
  module Market
    module OpenListings
      PER_PAGE = 24
      DEFAULT_SORT = "ending".freeze
      ORDERS = {
        "ending" => { ends_at: :asc, id: :asc },
        "price_asc" => { current_price: :asc, id: :asc },
        "price_desc" => { current_price: :desc, id: :asc },
        "newest" => { id: :desc }
      }.freeze

      Row = Data.define(:token, :card, :current_price, :buy_now_price, :ends_at, :offers)
      Page = Data.define(:rows, :more)

      def self.call(sort:, page:, locale:, filters: ListingFilters.none)
        sort = DEFAULT_SORT unless ORDERS.key?(sort)
        page = [ page.to_i, 1 ].max
        found = filters.apply(Listing.open_now, locale:).order(ORDERS.fetch(sort)).offset((page - 1) * PER_PAGE).limit(PER_PAGE + 1)
          .pluck(:id, :token, :card_season_id, :current_price, :buy_now_price, :ends_at)
        more = found.size > PER_PAGE
        found = found.first(PER_PAGE)
        cards = Catalog::CardViews.call(found.map { it[2] }, locale:)
        offers = OfferCounts.call(found.map(&:first))
        rows = found.filter_map do |id, token, card_season_id, current_price, buy_now_price, ends_at|
          card = cards[card_season_id]
          Row.new(token:, card:, current_price:, buy_now_price:, ends_at:, offers: offers[id]) if card
        end
        Page.new(rows:, more:)
      end
    end
  end
end
