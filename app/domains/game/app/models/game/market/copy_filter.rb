module Game
  module Market
    # What a player narrows their free copies to: words of the title, rarities, editions held twice or more or three times or more,
    # and, when `wanted_ids` is set, the editions other players want.
    class CopyFilter < Data.define(:query, :rarities, :doubles, :triples, :wanted_ids)
      MAX_QUERY = 100
      # Combining diacritical marks, left apart by NFD so a search ignores accents on both sides.
      MARKS = "[\u0300-\u036f]".freeze
      FOLDED = "lower(regexp_replace(normalize(%s, NFD), :marks, '', 'g'))".freeze

      def self.none = new

      def initialize(query: "", rarities: [], doubles: false, triples: false, wanted_ids: nil)
        super(query: query.to_s.strip.first(MAX_QUERY), rarities: Catalog::Rarity::TIERS.values.map(&:to_s) & Array(rarities).map(&:to_s),
          doubles: doubles == true, triples: triples == true, wanted_ids: wanted_ids&.map(&:to_i))
      end

      def wanted? = !wanted_ids.nil?

      def count = rarities.size + (doubles ? 1 : 0) + (triples ? 1 : 0) + (wanted? ? 1 : 0)

      def narrowing? = count.positive? || query.present?

      # Conditions on a list of holdings joined to their card texts as `localised` and `fallback`.
      def conditions
        [ ("AND (#{format(FOLDED, "localised.title")} LIKE :pattern OR #{format(FOLDED, "fallback.title")} LIKE :pattern)" if query.present?),
          ("AND catalog_card_seasons.rarity IN (:tiers)" if rarities.any?),
          ("AND game_holdings.quantity >= 2" if doubles), ("AND game_holdings.quantity >= 3" if triples),
          ("AND catalog_card_seasons.id IN (:wanted_ids)" if wanted?) ].compact.join(" ")
      end

      def binds
        { pattern: "%#{Holding.sanitize_sql_like(folded_query)}%", marks: MARKS, tiers: rarities.map { Catalog::Rarity::TIERS.key(it.to_sym) },
          wanted_ids: }
      end

      def folded_query = query.unicode_normalize(:nfd).gsub(Regexp.new(MARKS), "").downcase

      def to_params = { query:, rarities:, doubles: ("1" if doubles), triples: ("1" if triples), wanted: ("1" if wanted?) }.compact
    end
  end
end
