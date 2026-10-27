module Steam
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
