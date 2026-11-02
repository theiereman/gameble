module Catalog
  module StudioKeys
    def self.call(card_ids)
      return {} if card_ids.empty?

      Card.where(id: card_ids).pluck(:id, :developers).filter_map do |id, developers|
        key = developers.first&.then { SetNames.merge_form(SetNames.company(it)) }
        [ id, key ] if key.present?
      end.to_h
    end
  end
end
