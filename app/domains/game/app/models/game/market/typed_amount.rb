module Game
  module Market
    module TypedAmount
      MAX = 9_223_372_036_854_775_807
      FILTER_CEILING = 10**13
      PLAIN = /\A\d+\z/
      GROUPED = /\A\d{1,3}([ ,\u00A0\u202F])\d{3}(?:\1\d{3})*\z/
      EDGE_SPACES = /\A[[:space:]]+|[[:space:]]+\z/

      def self.digits(value)
        text = value.to_s.gsub(EDGE_SPACES, "")
        return text if PLAIN.match?(text)

        separator = text[GROUPED, 1]
        text.delete(separator) if separator
      end

      def self.whole_number(value) = digits(value)&.then { Integer(it, 10) }

      def self.price(value) = whole_number(value)&.then { it if it.between?(1, MAX) }

      def self.filter_bound(value) = (whole_number(value)&.then { it if it < FILTER_CEILING } if value.is_a?(String))
    end
  end
end
