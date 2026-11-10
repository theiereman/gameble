module Game
  module Market
    module EconomyAlerts
      Alert = Data.define(:indicator, :value, :threshold, :rarity, :current, :changes) do
        def actionable? = !changes.empty?

        def stamp_field = EconomyAlerts.stamp_field(rarity)

        def minimum_field = EconomyAlerts.minimum_field(rarity)
      end

      RULES = {
        destroyed_share: { side: :below, rarity: :rare },
        picoins_per_player: { side: :above, rarity: :rare },
        top_share: { side: :above, rarity: :legendary }
      }.freeze

      STAMP_RAISE = Rational(3, 2)

      def self.call(series, settings)
        return [] unless settings

        RULES.filter_map do |indicator, rule|
          point = series.public_send(indicator)
          alert(indicator, point.last, point.last_threshold, rule, settings)
        end
      end

      def self.stamp_field(rarity) = :"stamp_#{rarity}"

      def self.minimum_field(rarity) = :"minimum_price_#{rarity}"

      def self.named(name, series, settings) = call(series, settings).find { it.indicator.to_s == name.to_s }

      def self.alert(indicator, value, threshold, rule, settings)
        return if value.nil? || threshold.nil?
        return unless rule[:side] == :below ? value < threshold : value > threshold

        Alert.new(indicator:, value:, threshold:, rarity: rule[:rarity], current: current(settings, rule[:rarity]), changes: proposal(settings, rule[:rarity]))
      end
      private_class_method :alert

      def self.current(settings, rarity)
        [ stamp_field(rarity), minimum_field(rarity) ].index_with { settings.public_send(it) }
      end
      private_class_method :current

      def self.proposal(settings, rarity)
        rules = SettingsRules.new(settings)
        stamp = [ (settings.stamp(rarity) * STAMP_RAISE).ceil.ceildiv(100) * 100, rules.amount_limits(stamp_field(rarity)).last ].min
        floor = SettingsRules.floor(settings.entrustment(rarity), stamp, settings.commission_basis_points)
        changes = { stamp_field(rarity) => stamp, minimum_field(rarity) => [ settings.minimum_price(rarity), floor ].max }
        changes.reject! { |field, value| settings.public_send(field) == value }
        allowed?(rules, settings, changes) ? changes : {}
      end
      private_class_method :proposal

      def self.allowed?(rules, settings, changes)
        candidate = settings.attributes.symbolize_keys.slice(*SettingsRules::EDITABLE).merge(changes)
        rules.violations(candidate).empty?
      end
      private_class_method :allowed?
    end
  end
end
