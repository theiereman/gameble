module Game
  module Market
    # What a player narrows their free copies to: words of the title, rarities, and editions held twice or more.
    class CopyFilter < Data.define(:query, :rarities, :doubles)
      MAX_QUERY = 100
      # Combining diacritical marks, left apart by NFD so a search ignores accents on both sides.
      MARKS = "[\u0300-\u036f]".freeze
      FOLDED = "lower(regexp_replace(normalize(%s, NFD), :marks, '', 'g'))".freeze

      def self.none = new

      def initialize(query: "", rarities: [], doubles: false)
        super(query: query.to_s.strip.first(MAX_QUERY), rarities: Catalog::Rarity::TIERS.values.map(&:to_s) & Array(rarities).map(&:to_s),
          doubles: doubles == true)
      end

      def count = rarities.size + (doubles ? 1 : 0)

      def narrowing? = count.positive? || query.present?

      # Conditions on a list of holdings joined to their card texts as `localised` and `fallback`.
      def conditions
        [ ("AND (#{format(FOLDED, "localised.title")} LIKE :pattern OR #{format(FOLDED, "fallback.title")} LIKE :pattern)" if query.present?),
          ("AND catalog_card_seasons.rarity IN (:tiers)" if rarities.any?),
          ("AND game_holdings.quantity >= 2" if doubles) ].compact.join(" ")
      end

      def binds
        { pattern: "%#{Holding.sanitize_sql_like(folded_query)}%", marks: MARKS, tiers: rarities.map { Catalog::Rarity::TIERS.key(it.to_sym) } }
      end

      def folded_query = query.unicode_normalize(:nfd).gsub(Regexp.new(MARKS), "").downcase

      def to_params = { query:, rarities:, doubles: ("1" if doubles) }.compact
    end
  end
end
