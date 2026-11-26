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

      Row = Data.define(:token, :card, :current_price, :ends_at, :offers)
      Page = Data.define(:rows, :more)

      COLUMNS = %i[id token card_season_id current_price ends_at].freeze

      def self.call(sort:, page:, locale:, filters: ListingFilters.none)
        sort = DEFAULT_SORT unless ORDERS.key?(sort)
        page = [ page.to_i, 1 ].max
        found = filters.apply(Listing.open_now, locale:).order(ORDERS.fetch(sort)).offset((page - 1) * PER_PAGE).limit(PER_PAGE + 1).pluck(*COLUMNS)
        Page.new(rows: build(found.first(PER_PAGE), locale:), more: found.size > PER_PAGE)
      end

      def self.rows(relation, locale:) = build(relation.pluck(*COLUMNS), locale:)

      def self.count(locale:, filters: ListingFilters.none) = filters.apply(Listing.open_now, locale:).count

      def self.build(found, locale:)
        cards = Catalog::CardViews.call(found.map { it[2] }, locale:)
        offers = OfferCounts.call(found.map(&:first))
        found.filter_map do |id, token, card_season_id, current_price, ends_at|
          card = cards[card_season_id]
          Row.new(token:, card:, current_price:, ends_at:, offers: offers[id]) if card
        end
      end

      private_class_method :build
    end
  end
end
