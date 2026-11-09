require "test_helper"

class Game::FortuneIndexTest < ActiveSupport::TestCase
  test "the index is 500 tanh(Z/2), rounded, symmetrical around zero" do
    { -3 => -453, -2 => -381, -1 => -231, 0 => 0, 1 => 231, 2 => 381, 3 => 453, 3.52 => 471 }.each do |z_score, index|
      assert_equal index, Game::FortuneIndex.of(z_score), "Z = #{z_score}"
    end
    assert_equal 500, Game::FortuneIndex.of(40)
  end

  test "each band of the index has its title, from saint of commons to the RNG's favourite" do
    { 500 => :rngs_favourite, 490 => :rngs_favourite, 489 => :indecently_lucky, 450 => :indecently_lucky,
      449 => :probably_cheating, 375 => :probably_cheating, 374 => :enemy_of_merit, 300 => :enemy_of_merit,
      299 => :human_horseshoe, 200 => :suspiciously_lucky, 149 => :main_character, 100 => :main_character,
      60 => :smiled_upon, 0 => :aggressively_average, -49 => :aggressively_average, -50 => :mildly_annoyed,
      -100 => :ghosted_by_luck, -150 => :black_cat_friend, -231 => :punching_bag, -300 => :broke_a_mirror,
      -375 => :cursed_by_excel, -449 => :cursed_by_excel, -450 => :saint_of_commons, -500 => :saint_of_commons }
      .each { |index, label| assert_equal label, Game::FortuneIndex.label(index), "index #{index}" }
  end

  test "every title has its words in English and French, short enough for a phone" do
    (Game::FortuneIndex::LABELS.map(&:last) << Game::FortuneIndex::LUCKLESS).each do |label|
      %i[en fr].each do |locale|
        %w[title text].each { |part| assert I18n.exists?("fortunes.labels.#{label}.#{part}", locale), "#{locale} #{label} #{part}" }
        assert_operator I18n.t("fortunes.labels.#{label}.title", locale:).length, :<=, 20, "#{locale} #{label}"
      end
    end
  end

  test "the Privileged are a tenth of the week's active players, rounded up" do
    { 0 => 0, 1 => 1, 5 => 1, 10 => 1, 11 => 2, 25 => 3, 30 => 3, 100 => 10, 1_000 => 100 }.each do |active, privileged|
      assert_equal privileged, Game::FortuneIndex.privileged_count(active), "#{active} active"
    end
  end
end
