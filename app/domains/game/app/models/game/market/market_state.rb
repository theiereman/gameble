module Game
  module Market
    # Whether the market is open and whether it ever was, read from the settings version in force.
    MarketState = Data.define(:open, :first_opened_at) do
      def self.call(settings = CurrentSettings.call) = new(open: settings&.open || false, first_opened_at: settings&.first_opened_at)

      def open? = open

      def first_opened? = !first_opened_at.nil?

      def suspended? = first_opened? && !open?
    end
  end
end
