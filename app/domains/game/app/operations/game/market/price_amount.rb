module Game
  module Market
    module PriceAmount
      MAX_AMOUNT = 9_223_372_036_854_775_807

      private

      def amount(value)
        number = whole_number(value)
        number&.between?(1, MAX_AMOUNT) ? Success(number) : Failure(:invalid_price)
      end

      def whole_number(value)
        text = value.to_s.strip
        Integer(text, 10) if text.match?(/\A\d+\z/)
      end
    end
  end
end
