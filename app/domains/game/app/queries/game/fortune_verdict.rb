module Game
  module FortuneVerdict
    LAST_DAY = 3

    Verdict = Data.define(:player, :index) do
      def label = FortuneIndex.label(index)
    end

    def self.open?(now = Time.current) = now.utc.to_date.cwday <= LAST_DAY

    def self.call(now: Time.current) = (winner(now:) if open?(now))

    def self.winner(now: Time.current)
      fortune = Fortune.of_period(:last_week, now).ranked.where(player_id: Accounts::Player.visibility_public.select(:id)).first
      Verdict.new(player: Accounts::Player.find(fortune.player_id), index: FortuneIndex.of(fortune.z_score)) if fortune
    end
  end
end
