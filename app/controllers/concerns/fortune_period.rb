module FortunePeriod
  extend ActiveSupport::Concern

  ALL_TIME = "all_time"

  LAST_WEEK = "last_week"

  REGISTER_PERIODS = { ALL_TIME => :all_time, LAST_WEEK => :last_week }.freeze

  private
    def register_period(param)
      REGISTER_PERIODS.fetch(param, :week)
    end

    def fortune_period(param)
      param == ALL_TIME ? :all_time : :week
    end
end
