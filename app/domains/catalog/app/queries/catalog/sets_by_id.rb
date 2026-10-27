module Catalog
  module SetsById
    def self.call(set_ids)
      return {} if set_ids.empty?

      Set.where(id: set_ids.uniq).index_by(&:id)
    end
  end
end
