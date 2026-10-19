module Catalog
  # The kinds of set, in the library's tab order: the one list the sets'
  # enum, the routes, the controllers and the queries' order read.
  module SetKind
    ALL = %w[theme franchise studio hall_of_fame ufo].freeze

    # The kinds in ALL's order, anything else last.
    ORDER = Arel::Nodes::Case.new(Arel::Table.new(:catalog_sets)[:kind]).tap do |order|
      ALL.each_with_index { |kind, index| order.when(kind).then(index) }
    end.else(ALL.size).freeze

    PATTERN = Regexp.union(ALL)
  end
end
