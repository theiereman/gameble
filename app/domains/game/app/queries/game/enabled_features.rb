module Game
  module EnabledFeatures
    def self.call = FeatureFlag.where(enabled: true).pluck(:key).to_set
  end
end
