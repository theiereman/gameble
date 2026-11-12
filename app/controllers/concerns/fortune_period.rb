module FortunePeriod
  extend ActiveSupport::Concern

  ALL_TIME = "all_time"

  private
    def fortune_period(param)
      param == ALL_TIME ? :all_time : :week
    end
end
