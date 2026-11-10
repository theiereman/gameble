module Game
  module Market
    module AltSignals
      module CapsuleOpening
        def self.call(now:)
          last_midnight = now.utc.beginning_of_day
          window = (last_midnight - OPENING_WINDOW_DAYS.days)...last_midnight
          busy_days = Pack.where(opened_at: window).group(:player_id, Arel.sql("DATE(opened_at)"))
            .having("COUNT(*) >= ?", OPENING_CAPSULES_PER_DAY).count
          busy_days.group_by { |(player_id, _day), _opened| player_id }.filter_map { |player_id, days| detected(player_id, days.map(&:last)) }
        end

        def self.detected(player_id, opened_per_day)
          return if opened_per_day.size < OPENING_DAYS_REQUIRED

          Detected.new(account_id: player_id, signal: "near_maximum_opening", other_account_id: nil,
            facts: { "days" => opened_per_day.size, "peak" => opened_per_day.max, "per_day" => OPENING_CAPSULES_PER_DAY })
        end

        private_class_method :detected
      end
    end
  end
end
