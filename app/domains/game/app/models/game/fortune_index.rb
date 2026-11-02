module Game
  module FortuneIndex
    LIMIT = 500

    PRIVILEGED_PER = 10

    LABELS = [
      [ 490, :chosen_by_the_rng ],
      [ 450, :indecently_lucky ],
      [ 375, :suspected_of_rigging ],
      [ 300, :enemy_of_meritocracy ],
      [ 225, :walking_lucky_charm ],
      [ 150, :suspiciously_fortunate ],
      [ 100, :on_a_good_streak ],
      [ 50, :favored_by_probability ],
      [ -49, :statistically_ordinary ],
      [ -99, :mildly_inconvenienced ],
      [ -149, :overlooked_by_fortune ],
      [ -224, :black_cat_owner ],
      [ -299, :shunned_by_the_odds ],
      [ -374, :seven_years_of_commons ],
      [ -449, :statistically_cursed ]
    ].freeze

    LUCKLESS = :patron_saint_of_commons

    def self.of(z_score) = (LIMIT * Math.tanh(z_score.to_f / 2)).round

    def self.label(index)
      LABELS.find { |floor, _| index >= floor }&.last || LUCKLESS
    end

    def self.privileged_count(active_players) = active_players.ceildiv(PRIVILEGED_PER)
  end
end
