class AveragePriceComponent < ViewComponent::Base
  def initialize(price:, compact: false, **html_options)
    @price = price
    @compact = compact
    @html_options = html_options
  end

  def render? = !@price.nil?

  private
    def classes
      [ "average-price", ("average-price--none" if @price.no_sale?), @html_options[:class] ].compact.join(" ")
    end
end
