module Game
  module FortunePanel
    TOP = 3

    Panel = Data.define(:tab, :period, :verdict, :standing, :distribution, :top)

    def self.call(viewer, tab:, now: Time.current)
      verdict = FortuneVerdict.call(now:) unless tab == :all_time
      period = tab == :all_time ? :all_time : (verdict ? :last_week : :week)
      Panel.new(tab:, period:, verdict:, standing: FortuneStanding.call(viewer, period:, now:),
        distribution: FortuneDistribution.call(period, now:), top: top(period, viewer, now))
    end

    def self.top(period, viewer, now)
      fortunes = FortuneBoard.ranked(period, now:).limit(TOP).to_a
      FortuneBoard.rows(fortunes, ranked_count: Fortune.of_period(period, now).listed.count, viewer:, now:)
    end

    private_class_method :top
  end
end
