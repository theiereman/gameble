module Catalog
  # How many cards each set holds (CAP-6), in one grouped query; none for no
  # set.
  #
  #   Catalog::SetTotals.call([ set_id, … ]) # => { set_id => member count }
  module SetTotals
    def self.call(set_ids)
      return {} if set_ids.empty?

      SetMembership.where(set_id: set_ids).group(:set_id).count
    end
  end
end
