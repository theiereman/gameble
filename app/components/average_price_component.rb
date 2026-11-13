class AveragePriceComponent < ViewComponent::Base
  def initialize(price:, compact: false, flag_few_sales: true, **html_options)
    @price = price
    @compact = compact
    @flag_few_sales = flag_few_sales
    @html_options = html_options
  end

  def render? = !@price.nil?

  private
    def few_sales_flagged? = @flag_few_sales && @price.few_sales?

    def classes
      [ "average-price", ("average-price--none" if @price.no_sale?), @html_options[:class] ].compact.join(" ")
    end
end
