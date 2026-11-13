module Game
  module Market
    module PriceAmount
      MAX_AMOUNT = TypedAmount::MAX

      private

      def amount(value)
        number = TypedAmount.price(value)
        number ? Success(number) : Failure(:invalid_price)
      end

      def whole_number(value)
        text = value.to_s.strip
        Integer(text, 10) if text.match?(TypedAmount::PLAIN)
      end
    end
  end
end
