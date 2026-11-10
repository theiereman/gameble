class PicoinAmountComponent < ViewComponent::Base
  MARKS = { small: "picoin-mark", large: "picoin-mark-large" }.freeze

  def initialize(amount:, compact: false, size: :small, **html_options)
    @amount = amount
    @compact = compact
    @size = size
    @html_options = html_options
    @mark = MARKS.fetch(size) { raise ArgumentError, "unknown PiCoin amount size: #{size.inspect}" }
  end

  private
    attr_reader :mark

    def classes
      [ "picoin-amount", ("picoin-amount--large" if @size == :large), @html_options[:class] ].compact.join(" ")
    end

    def accessible_name
      t("picoin_amount.accessible", amount: helpers.picoins(@amount))
    end

    def figure
      helpers.picoins(@amount, compact: @compact)
    end
end
