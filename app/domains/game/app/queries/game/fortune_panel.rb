module Game
  module FortunePanel
    TOP = 3

    Panel = Data.define(:verdict, :standing, :distribution, :privileged_floor, :top)

    def self.call(viewer, now: Time.current)
      distribution = FortuneDistribution.call(now:)
      Panel.new(verdict: FortuneVerdict.call(now:), standing: FortuneStanding.call(viewer, period: :week, now:), distribution:,
        privileged_floor: Privileged.floor_index(now:), top: top(viewer, now, distribution.total))
    end

    def self.top(viewer, now, ranked_count)
      fortunes = FortuneBoard.ranked(now:).limit(TOP).to_a
      return [] if fortunes.empty?

      FortuneBoard.rows(fortunes, ranked_count:, viewer:, now:)
    end

    private_class_method :top
  end
end
