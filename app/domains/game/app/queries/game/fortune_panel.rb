module Game
  module FortunePanel
    TOP = 3

    Panel = Data.define(:tab, :period, :verdict, :standing, :distribution, :top)

    def self.call(viewer, tab:, now: Time.current)
      verdict = FortuneVerdict.call(now:) unless tab == :all_time
      period = tab == :all_time ? :all_time : (verdict ? :last_week : :week)
      distribution = FortuneDistribution.call(period, now:)
      Panel.new(tab:, period:, verdict:, standing: FortuneStanding.call(viewer, period:, now:), distribution:,
        top: top(period, viewer, now, distribution.total))
    end

    def self.top(period, viewer, now, ranked_count)
      fortunes = FortuneBoard.ranked(period, now:).limit(TOP).to_a
      return [] if fortunes.empty?

      FortuneBoard.rows(fortunes, ranked_count:, viewer:, now:, with_rarities: false)
    end

    private_class_method :top
  end
end
