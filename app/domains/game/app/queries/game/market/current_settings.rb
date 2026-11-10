module Game
  module Market
    # The settings version in force: the highest id, read from the database every time.
    module CurrentSettings
      def self.call = Settings.order(:id).last
    end
  end
end
