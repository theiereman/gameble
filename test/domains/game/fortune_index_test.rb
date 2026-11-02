require "test_helper"

class Game::FortuneIndexTest < ActiveSupport::TestCase
  test "the index is 500 tanh(Z/2), rounded, symmetrical around zero" do
    { -3 => -453, -2 => -381, -1 => -231, 0 => 0, 1 => 231, 2 => 381, 3 => 453, 3.52 => 471 }.each do |z_score, index|
      assert_equal index, Game::FortuneIndex.of(z_score), "Z = #{z_score}"
    end
    assert_equal 500, Game::FortuneIndex.of(40)
  end

  test "each band of the index has its title, from patron saint of commons to chosen by the RNG" do
    { 500 => :chosen_by_the_rng, 490 => :chosen_by_the_rng, 489 => :indecently_lucky, 450 => :indecently_lucky,
      449 => :suspected_of_rigging, 375 => :suspected_of_rigging, 374 => :enemy_of_meritocracy, 300 => :enemy_of_meritocracy,
      299 => :walking_lucky_charm, 200 => :suspiciously_fortunate, 149 => :on_a_good_streak, 100 => :on_a_good_streak,
      60 => :favored_by_probability, 0 => :statistically_ordinary, -49 => :statistically_ordinary, -50 => :mildly_inconvenienced,
      -100 => :overlooked_by_fortune, -150 => :black_cat_owner, -231 => :shunned_by_the_odds, -300 => :seven_years_of_commons,
      -375 => :statistically_cursed, -449 => :statistically_cursed, -450 => :patron_saint_of_commons, -500 => :patron_saint_of_commons }
      .each { |index, label| assert_equal label, Game::FortuneIndex.label(index), "index #{index}" }
  end

  test "every title has its words in English and French" do
    (Game::FortuneIndex::LABELS.map(&:last) << Game::FortuneIndex::LUCKLESS).each do |label|
      %i[en fr].each do |locale|
        %w[title text].each { |part| assert I18n.exists?("fortunes.labels.#{label}.#{part}", locale), "#{locale} #{label} #{part}" }
      end
    end
  end

  test "the Privileged are a tenth of the week's active players, rounded up" do
    { 0 => 0, 1 => 1, 5 => 1, 10 => 1, 11 => 2, 25 => 3, 30 => 3, 100 => 10, 1_000 => 100 }.each do |active, privileged|
      assert_equal privileged, Game::FortuneIndex.privileged_count(active), "#{active} active"
    end
  end
end
