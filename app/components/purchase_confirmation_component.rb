# The body of a dialog confirming a purchase at a fixed price: what is bought, the price, the balance after it, then the buttons
# the state allows; a lead, when given, under the title. `state`: :buyable draws the form, :short the missing amount and the way to earn it, :closed and :capped only the cancel button.
class PurchaseConfirmationComponent < ViewComponent::Base
  STATES = %i[buyable short closed capped].freeze

  renders_one :lead
  renders_one :visual
  renders_one :facts
  renders_one :note

  def initialize(title:, title_id:, state:, price: nil, available: nil, url: nil, fields: {}, refusal: nil, missing_line: nil, entrust: true)
    raise ArgumentError, "unknown purchase state: #{state.inspect}" unless STATES.include?(state)
    raise ArgumentError, "a buyable purchase needs a price and a url" if state == :buyable && (price.nil? || url.nil?)

    @title = title
    @title_id = title_id
    @state = state
    @price = price
    @available = available
    @url = url
    @fields = fields
    @refusal = refusal
    @missing_line = missing_line
    @entrust = entrust
  end

  private
    attr_reader :title, :title_id, :state, :price, :url, :fields, :refusal, :missing_line

    def short? = state == :short

    def entrust? = @entrust

    def balance_after = (@available - price if state == :buyable && @available)
end
