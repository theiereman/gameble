module Catalog
  module SetKind
    ALL = %w[theme franchise studio hall_of_fame ufo].freeze

    ORDER = Arel::Nodes::Case.new(Arel::Table.new(:catalog_sets)[:kind]).tap do |order|
      ALL.each_with_index { |kind, index| order.when(kind).then(index) }
    end.else(ALL.size).freeze

    PATTERN = Regexp.union(ALL)
  end
end
