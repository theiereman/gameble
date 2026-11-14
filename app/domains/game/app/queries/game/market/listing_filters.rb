module Game
  module Market
    class ListingFilters
      MAX_QUERY = 100
      MAX_CHOICES = 50

      SetChoice = Data.define(:kind, :key) do
        def to_param = "#{kind}:#{key}"
      end

      attr_reader :query, :rarities, :sets, :genres, :seasons, :min_price, :max_price, :hidden_seller, :wanted_card_ids

      def self.wanted(card_ids) = none.with(wanted_card_ids: card_ids)

      def self.from(params, genres: [], seasons: [], viewer: nil, wanted_card_ids: [])
        new(
          query: text(params[:q]).first(MAX_QUERY),
          rarities: Catalog::Rarity::TIERS.values.map(&:to_s) & strings(params[:rarity]),
          sets: set_choices(params[:sets]),
          genres: genres & strings(params[:genre]),
          seasons: seasons & strings(params[:season]).filter_map { Integer(it, 10, exception: false) },
          min_price: price(params[:min_price]),
          max_price: price(params[:max_price]),
          hidden_seller: (viewer if params[:hide_mine] == "1"),
          wanted_card_ids: (wanted_card_ids if params[:wanted] == "1")
        )
      end

      def self.none = new(query: "", rarities: [], sets: [], genres: [], seasons: [], min_price: nil, max_price: nil)

      def self.text(value) = value.is_a?(String) ? value.delete("\0").strip : ""

      def self.strings(value) = Array(value).grep(String).map(&:strip).uniq.first(MAX_CHOICES)

      def self.set_choices(value)
        strings(value).filter_map do |choice|
          kind, key = choice.split(":", 2)
          SetChoice.new(kind:, key:) if Catalog::SetKind::ALL.include?(kind) && key&.match?(Catalog::Set::KEY_FORMAT)
        end
      end

      def self.price(value) = TypedAmount.filter_bound(value)

      private_class_method :text, :strings, :set_choices, :price

      def initialize(query:, rarities:, sets:, genres:, seasons:, min_price:, max_price:, hidden_seller: nil, wanted_card_ids: nil)
        @query = query
        @rarities = rarities
        @sets = sets
        @genres = genres
        @seasons = seasons
        @min_price = min_price
        @max_price = max_price
        @hidden_seller = hidden_seller
        @wanted_card_ids = wanted_card_ids
      end

      def only_sets(known) = with(sets: sets.select { known.include?([ it.kind, it.key ]) })

      def count = rarities.size + sets.size + genres.size + seasons.size + [ min_price, max_price ].compact.size

      def hides_mine? = hidden_seller.present?

      def wanted_only? = !wanted_card_ids.nil?

      def any? = count.positive? || query.present? || hides_mine? || wanted_only?

      def without_query = with(query: "")

      def to_params
        { q: query, rarity: rarities, sets: sets.map(&:to_param), genre: genres, season: seasons, min_price:, max_price:,
          hide_mine: ("1" if hides_mine?), wanted: ("1" if wanted_only?) }.compact_blank
      end

      def apply(listings, locale:)
        listings = listings.where(current_price: min_price..) if min_price
        listings = listings.where(current_price: ..max_price) if max_price
        listings = listings.where.not(seller: hidden_seller) if hides_mine?
        listings = listings.where(card_season_id: Catalog::CardSeason.where(card_id: wanted_card_ids).select(:id)) if wanted_only?
        about_cards? ? listings.where(card_season_id: card_seasons(locale).select(:id)) : listings
      end

      def with(**changes)
        self.class.new(**{ query:, rarities:, sets:, genres:, seasons:, min_price:, max_price:, hidden_seller:, wanted_card_ids: }.merge(changes))
      end

      private

      def about_cards? = [ rarities, genres, seasons, sets ].any?(&:any?) || query.present?

      def card_seasons(locale)
        cards = Catalog::CardSeason.all
        cards = cards.where(rarity: rarities) if rarities.any?
        cards = cards.where(main_theme: genres) if genres.any?
        cards = cards.where(season_id: Catalog::Season.where(number: seasons).select(:id)) if seasons.any?
        cards = cards.where(id: Catalog::SetMembership.where(set_id: chosen_sets).select(:card_season_id)) if sets.any?
        query.present? ? cards.where(title_match(locale)) : cards
      end

      def chosen_sets = sets.map { Catalog::Set.where(kind: it.kind, key: it.key) }.reduce(:or).select(:id)

      def title_match(locale)
        pattern = "%#{Catalog::Set.sanitize_sql_like(query)}%"
        Catalog::CardSeason.sanitize_sql_array([
          "catalog_card_seasons.card_id IN (SELECT card_id FROM catalog_card_texts WHERE locale = ? AND title ILIKE ?) " \
          "OR catalog_card_seasons.card_id IN (SELECT id FROM catalog_cards WHERE publisher ILIKE ?)",
          locale.to_s, pattern, pattern
        ])
      end
    end
  end
end
