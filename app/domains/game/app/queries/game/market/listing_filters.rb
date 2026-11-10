module Game
  module Market
    class ListingFilters
      MAX_QUERY = 100
      MAX_CHOICES = 50
      PRICE_FORMAT = /\A\d{1,13}\z/

      SetChoice = Data.define(:kind, :key) do
        def to_param = "#{kind}:#{key}"
      end

      attr_reader :query, :rarities, :sets, :genres, :seasons, :min_price, :max_price

      def self.from(params, genres: [], seasons: [])
        new(
          query: text(params[:q]).first(MAX_QUERY),
          rarities: Catalog::Rarity::TIERS.values.map(&:to_s) & strings(params[:rarity]),
          sets: set_choices(params[:sets]),
          genres: genres & strings(params[:genre]),
          seasons: seasons & strings(params[:season]).filter_map { Integer(it, 10, exception: false) },
          min_price: price(params[:min_price]),
          max_price: price(params[:max_price])
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

      def self.price(value) = (Integer(value, 10) if value.is_a?(String) && value.strip.match?(PRICE_FORMAT))

      private_class_method :text, :strings, :set_choices, :price

      def initialize(query:, rarities:, sets:, genres:, seasons:, min_price:, max_price:)
        @query = query
        @rarities = rarities
        @sets = sets
        @genres = genres
        @seasons = seasons
        @min_price = min_price
        @max_price = max_price
      end

      def only_sets(known) = with(sets: sets.select { known.include?([ it.kind, it.key ]) })

      def count = rarities.size + sets.size + genres.size + seasons.size + [ min_price, max_price ].compact.size

      def any? = count.positive? || query.present?

      def to_params
        { q: query, rarity: rarities, sets: sets.map(&:to_param), genre: genres, season: seasons, min_price:, max_price: }.compact_blank
      end

      def apply(listings, locale:)
        listings = listings.where(current_price: min_price..) if min_price
        listings = listings.where(current_price: ..max_price) if max_price
        about_cards? ? listings.where(card_season_id: card_seasons(locale).select(:id)) : listings
      end

      private

      def with(**changes)
        self.class.new(**{ query:, rarities:, sets:, genres:, seasons:, min_price:, max_price: }.merge(changes))
      end

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
