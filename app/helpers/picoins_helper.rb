# PiCoin amounts are integers: the exact form groups thousands, the compact form truncates (never rounds up) to one decimal from 1,000.
module PicoinsHelper
  COMPACT_UNITS = [ [ 1_000_000, "M" ], [ 1_000, "k" ] ].freeze

  def picoins(amount, compact: false)
    amount = Integer(amount)
    return number_with_delimiter(amount) unless compact && amount >= 1_000

    divisor, suffix = COMPACT_UNITS.find { |threshold, _| amount >= threshold }
    tenths = amount * 10 / divisor
    whole, tenth = tenths.divmod(10)
    number = tenth.zero? ? number_with_delimiter(whole) : "#{number_with_delimiter(whole)}#{t("number.format.separator")}#{tenth}"
    "#{number}#{suffix}"
  end
end
