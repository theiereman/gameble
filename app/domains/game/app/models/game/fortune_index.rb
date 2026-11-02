module Game
  module FortuneIndex
    LIMIT = 500

    PRIVILEGED_PER = 10

    LABELS = [
      [ 450, :indecently_lucky ],
      [ 300, :enemy_of_meritocracy ],
      [ 150, :suspiciously_fortunate ],
      [ 50, :favored_by_probability ],
      [ -49, :statistically_ordinary ],
      [ -149, :overlooked_by_fortune ],
      [ -399, :shunned_by_the_odds ]
    ].freeze

    CURSED = :statistically_cursed

    def self.of(z_score) = (LIMIT * Math.tanh(z_score.to_f / 2)).round

    def self.label(index)
      LABELS.find { |floor, _| index >= floor }&.last || CURSED
    end

    def self.privileged_count(active_players) = active_players.ceildiv(PRIVILEGED_PER)
  end
end
