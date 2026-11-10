module Game
  module Market
    module PriceAmount
      MAX_AMOUNT = 9_223_372_036_854_775_807

      private

      def amount(value)
        text = value.to_s.strip
        number = Integer(text, 10) if text.match?(/\A\d+\z/)
        number&.between?(1, MAX_AMOUNT) ? Success(number) : Failure(:invalid_price)
      end
    end
  end
end
