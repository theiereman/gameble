# PiCoin amounts are integers: the exact form groups thousands, the compact form truncates (never rounds up) to one decimal from 1,000.
module PicoinsHelper
  COMPACT_UNITS = [ [ 1_000_000, "M", :millions ], [ 1_000, "k", :thousands ] ].freeze

  def picoins(amount, compact: false)
    amount = whole_picoins(amount)
    return number_with_delimiter(amount) unless compact && amount >= 1_000

    number, suffix = compact_picoins_parts(amount)
    "#{number}#{suffix}"
  end

  def compact_picoins_parts(amount)
    amount = whole_picoins(amount)
    divisor, suffix, name = COMPACT_UNITS.find { |threshold, _| amount >= threshold }
    return if divisor.nil?

    whole, tenth = (amount * 10 / divisor).divmod(10)
    number = tenth.zero? ? number_with_delimiter(whole) : "#{number_with_delimiter(whole)}#{t("number.format.separator")}#{tenth}"
    [ number, suffix, name, whole + (tenth / 10.0) ]
  end

  def picoins_label(amount)
    t("picoin_amount.accessible", amount: picoins(amount))
  end

  private
    def whole_picoins(amount)
      amount = Integer(amount) if amount.is_a?(String) && amount.match?(/\A\d+\z/)
      raise ArgumentError, "a PiCoin amount is a non-negative integer" unless amount.is_a?(Integer) && amount >= 0

      amount
    end
end
