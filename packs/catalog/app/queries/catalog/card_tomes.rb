module Catalog
  # The tome of each of the card-seasons given (their sets are those of their
  # own season), in one query: the set the whole-season collection's links
  # name, so the card detail browses it and shows a card the viewer does not
  # hold as their faded card back (epic 10 R2; EXPERIENCE.md, Missing-card
  # slot). A card-season sits in one tome at most (as CardViews::GENRE finds
  # it); one in no tome, or an unknown id, is left out. The tome is answered
  # as a SetSlots::SetRef (kind, key, params): AD-15, no id leaves the server.
  #
  #   Catalog::CardTomes.call([ 12, 7 ])
  #   # => { 12 => SetRef(kind: "tome", key: "action-1", params: { … }) }
  module CardTomes
    def self.call(card_season_ids)
      return {} if card_season_ids.empty?

      SetMembership.joins(:set)
        .where(card_season_id: card_season_ids.uniq, catalog_sets: { kind: "tome" })
        .order(:card_season_id, :id)
        .pluck(:card_season_id, Arel.sql("catalog_sets.kind"), Arel.sql("catalog_sets.key"), Arel.sql("catalog_sets.params"))
        .each_with_object({}) do |(id, kind, key, params), tomes|
          tomes[id] ||= SetSlots::SetRef.new(kind:, key:, params:)
        end
    end
  end
end
