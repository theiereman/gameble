module Catalog
  # What promoting a staged batch would do to the draft season, for the
  # administrator's review: the batch's panel (the same preview as a
  # draft's, rarity spread included), the gap with the draft's cards, and the
  # draft's own panel to compare the spreads. Reads, writes nothing.
  #
  # - `added`: cards the batch stages that the draft does not hold
  # - `removed`: cards the draft holds that the batch does not stage
  # - `rescored`: cards in both whose prestige score differs
  # - `draft_panel`: nil when the draft holds no card
  #
  #   Catalog::StagedBatchReview.call(run.token)
  module StagedBatchReview
    Review = Data.define(:staged_count, :draft_count, :added, :removed, :rescored, :panel, :draft_panel)

    def self.call(batch_token)
      staged = SeasonRows.staged(batch_token)
      draft = SeasonRows.call(Season.draft.select(:id))
      staged_scores = staged.to_h { |row| [ row.card_id, row.prestige_score ] }
      draft_scores = draft.to_h { |row| [ row.card_id, row.prestige_score ] }

      Review.new(
        staged_count: staged.size,
        draft_count: draft.size,
        added: (staged_scores.keys - draft_scores.keys).size,
        removed: (draft_scores.keys - staged_scores.keys).size,
        rescored: staged_scores.count { |card_id, score| draft_scores.key?(card_id) && draft_scores[card_id] != score },
        panel: DraftPreview.of(staged),
        draft_panel: draft.empty? ? nil : DraftPreview.of(draft)
      )
    end
  end
end
