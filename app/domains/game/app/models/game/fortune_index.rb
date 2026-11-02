module Game
  module FortuneIndex
    LIMIT = 500

    PRIVILEGED_PER = 10

    LABELS = [
      [ 490, :rngs_favourite ],
      [ 450, :indecently_lucky ],
      [ 375, :probably_cheating ],
      [ 300, :enemy_of_merit ],
      [ 225, :human_horseshoe ],
      [ 150, :suspiciously_lucky ],
      [ 100, :main_character ],
      [ 50, :smiled_upon ],
      [ -49, :aggressively_average ],
      [ -99, :mildly_annoyed ],
      [ -149, :ghosted_by_luck ],
      [ -224, :black_cat_friend ],
      [ -299, :punching_bag ],
      [ -374, :broke_a_mirror ],
      [ -449, :cursed_by_excel ]
    ].freeze

    LUCKLESS = :saint_of_commons

    def self.of(z_score) = (LIMIT * Math.tanh(z_score.to_f / 2)).round

    def self.label(index)
      LABELS.find { |floor, _| index >= floor }&.last || LUCKLESS
    end

    def self.privileged_count(active_players) = active_players.ceildiv(PRIVILEGED_PER)
  end
end
