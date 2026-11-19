module Game
  class EnabledFeatures < ActiveSupport::CurrentAttributes
    attribute :keys

    def self.call = (self.keys ||= FeatureFlag.where(enabled: true).pluck(:key).to_set)

    def self.reload
      self.keys = nil
    end
  end
end
