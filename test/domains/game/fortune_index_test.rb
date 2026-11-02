require "test_helper"

class Game::FortuneIndexTest < ActiveSupport::TestCase
  test "the index is 500 tanh(Z/2), rounded, symmetrical around zero" do
    { -3 => -453, -2 => -381, -1 => -231, 0 => 0, 1 => 231, 2 => 381, 3 => 453, 3.52 => 471 }.each do |z_score, index|
      assert_equal index, Game::FortuneIndex.of(z_score), "Z = #{z_score}"
    end
    assert_equal 500, Game::FortuneIndex.of(40)
  end

  test "each band of the index has its label, from cursed to indecently lucky" do
    { 471 => :indecently_lucky, 450 => :indecently_lucky, 449 => :enemy_of_meritocracy, 200 => :suspiciously_fortunate,
      60 => :favored_by_probability, 0 => :statistically_ordinary, -49 => :statistically_ordinary, -50 => :overlooked_by_fortune,
      -231 => :shunned_by_the_odds, -399 => :shunned_by_the_odds, -400 => :statistically_cursed, -453 => :statistically_cursed }.each do |index, label|
      assert_equal label, Game::FortuneIndex.label(index), "index #{index}"
    end
  end

  test "the Privileged are a tenth of the week's active players, rounded up" do
    { 0 => 0, 1 => 1, 5 => 1, 10 => 1, 11 => 2, 25 => 3, 30 => 3, 100 => 10, 1_000 => 100 }.each do |active, privileged|
      assert_equal privileged, Game::FortuneIndex.privileged_count(active), "#{active} active"
    end
  end
end
