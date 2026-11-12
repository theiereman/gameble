module Game
  module Market
    module ChartPublications
      EXCHANGE_KINDS = %w[reactor rarity_prices].freeze

      Switch = Data.define(:kind, :published, :published_at)

      Visibility = Data.define(:visible_kinds, :published_kinds) do
        def visible?(kind) = visible_kinds.include?(kind.to_s)

        def staff_only?(kind) = visible?(kind) && !published_kinds.include?(kind.to_s)

        def exchange? = visible_kinds.intersect?(EXCHANGE_KINDS)
      end

      def self.published_kinds = ChartPublication.order(:id).select(&:published?).map(&:kind)

      def self.visible_kinds(viewer) = self.for(viewer).visible_kinds

      def self.for(viewer)
        published = published_kinds
        Visibility.new(visible_kinds: viewer&.staff? ? ChartPublication::KINDS : published, published_kinds: published)
      end

      def self.switches
        publications = ChartPublication.all.index_by(&:kind)
        ChartPublication::KINDS.map do |kind|
          publication = publications[kind]
          published = publication&.published? || false
          Switch.new(kind:, published:, published_at: (publication.published_at if published))
        end
      end
    end
  end
end
