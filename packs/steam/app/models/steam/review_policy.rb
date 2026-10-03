module Steam
  # The review floor of the catalog (catalog-and-rarity.md, Inclusion): a game
  # is kept with at least MIN_REVIEWS Steam reviews. Turns a GetItems store
  # item into the review summary and verdict stored on its Steam::App.
  #
  #   Steam::ReviewPolicy.verdict(item)
  #   # => #<data Steam::ReviewPolicy::Verdict review_count: 812, review_percent_positive: 93, reviews: {...}, exclusion: nil>
  #
  # An item missing from Steam's answer (nil) or answered with a `success`
  # other than 1 is unavailable; a store item without reviews counts 0. A
  # count present but not an Integer from 0 to 2**31 - 1, or a count at the
  # floor with a percent that is not an Integer from 0 to 100, is
  # malformed_reviews (Steam::RawValue): the value Steam gave is not stored
  # (NULL), so a card is never scored from it.
  module ReviewPolicy
    MIN_REVIEWS = 500

    TOO_FEW_REVIEWS = "too_few_reviews".freeze
    UNAVAILABLE = "unavailable".freeze
    MALFORMED_REVIEWS = "malformed_reviews".freeze
    EXCLUSIONS = [ TOO_FEW_REVIEWS, UNAVAILABLE, MALFORMED_REVIEWS ].freeze

    Verdict = Data.define(:review_count, :review_percent_positive, :reviews, :exclusion) do
      def kept?
        exclusion.nil?
      end
    end

    def self.verdict(item)
      return Verdict.new(review_count: nil, review_percent_positive: nil, reviews: nil, exclusion: UNAVAILABLE) unless item.is_a?(Hash) && item["success"] == 1

      reviews = item["reviews"].is_a?(Hash) ? RawValue.scrub(item["reviews"]) : nil
      summary = RawValue.object(reviews&.fetch("summary_filtered", nil))
      count = summary["review_count"].nil? ? 0 : RawValue.integer(summary["review_count"], min: 0, max: RawValue::INT4_MAX)
      percent = RawValue.integer(summary["percent_positive"], min: 0, max: 100)

      Verdict.new(review_count: count, review_percent_positive: percent, reviews: reviews, exclusion: exclusion(count, percent))
    end

    def self.exclusion(count, percent)
      if count.nil? then MALFORMED_REVIEWS
      elsif count < MIN_REVIEWS then TOO_FEW_REVIEWS
      elsif percent.nil? then MALFORMED_REVIEWS
      end
    end
    private_class_method :exclusion
  end
end
