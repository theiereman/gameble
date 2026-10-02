module Steam
  # The review floor of the catalog (catalog-and-rarity.md, Inclusion): a game
  # is kept with at least MIN_REVIEWS Steam reviews. Turns a GetItems store
  # item into the review summary and verdict stored on its Steam::App.
  #
  #   Steam::ReviewPolicy.verdict(item)
  #   # => #<data Steam::ReviewPolicy::Verdict review_count: 812, review_percent_positive: 93, reviews: {...}, exclusion: nil>
  #
  # An item missing from Steam's answer (nil) or answered with a `success`
  # other than 1 is unavailable; a store item without reviews counts 0.
  module ReviewPolicy
    MIN_REVIEWS = 500

    TOO_FEW_REVIEWS = "too_few_reviews".freeze
    UNAVAILABLE = "unavailable".freeze
    EXCLUSIONS = [ TOO_FEW_REVIEWS, UNAVAILABLE ].freeze

    Verdict = Data.define(:review_count, :review_percent_positive, :reviews, :exclusion) do
      def kept?
        exclusion.nil?
      end
    end

    def self.verdict(item)
      return Verdict.new(review_count: nil, review_percent_positive: nil, reviews: nil, exclusion: UNAVAILABLE) unless item.is_a?(Hash) && item["success"] == 1

      reviews = item["reviews"].is_a?(Hash) ? item["reviews"] : nil
      summary = reviews&.dig("summary_filtered")
      summary = {} unless summary.is_a?(Hash)
      count = summary["review_count"].to_i
      percent = summary["percent_positive"]&.to_i

      Verdict.new(
        review_count: count,
        review_percent_positive: percent,
        reviews: reviews,
        exclusion: count >= MIN_REVIEWS ? nil : TOO_FEW_REVIEWS
      )
    end
  end
end
