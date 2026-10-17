module Catalog
  # The sets of `set_ids`, in one query; an unknown id is left out.
  #
  #   Catalog::SetsById.call([ set_id, … ]) # => { set_id => Catalog::Set }
  module SetsById
    def self.call(set_ids)
      return {} if set_ids.empty?

      Set.where(id: set_ids.uniq).index_by(&:id)
    end
  end
end
