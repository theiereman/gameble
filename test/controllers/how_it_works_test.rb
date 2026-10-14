require "test_helper"
require_relative "../support/steam_sign_in"

# The how-it-works screen: the rules of the game for a visitor and a player,
# every number checked against the constant the game applies, computed here
# rather than through the screen's helper.
class HowItWorksTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  FRENCH_HEADINGS = [
    "Quels jeux deviennent des cartes", "La rareté", "Boosters et probabilités", "Le rythme des boosters",
    "Le booster quotidien", "L'objectif communautaire", "Les saisons", "Les sets", "Compléter un set"
  ].freeze

  ENGLISH_HEADINGS = [
    "Which games become cards", "Rarity", "Boosters and odds", "The pace of boosters",
    "The daily booster", "The community goal", "Seasons", "Sets", "Completing a set"
  ].freeze

  # `parts` out of `whole` as a percent with at most two decimals, written
  # the way the locale writes it.
  def expected_percent(parts, whole, locale)
    integer, fraction = (BigDecimal(parts) * 100 / whole).round(2).to_s("F").split(".")
    fraction = fraction.to_s.sub(/0+\z/, "")
    number = fraction.empty? ? integer : [ integer, fraction ].join(locale == :fr ? "," : ".")
    locale == :fr ? "#{number} %" : "#{number}%"
  end

  def shown_value(percent)
    BigDecimal(percent.delete("%  ").tr(",", "."))
  end

  def rarity_name(tier, locale)
    I18n.t("catalog.rarity.#{Catalog::Rarity::TIERS.fetch(tier)}", locale:)
  end

  def odds_tables
    {
      "regular" => Game::DrawOdds::REGULAR, "bonus" => Game::DrawOdds::BONUS,
      "reward" => Game::DrawOdds::REWARD, "epic_or_better" => Game::DrawOdds::EPIC_OR_BETTER
    }
  end

  def rows_of(selector)
    css_select(selector).map { [ it.at_css(".how-it-works__name").text.strip, it.at_css(".how-it-works__percent").text.strip ] }
  end

  def assert_every_odds_table(locale)
    odds_tables.each do |name, odds|
      rows = rows_of("table.how-it-works__odds[data-odds=#{name}] tbody tr")
      expected = odds.sort.map { |tier, parts| [ rarity_name(tier, locale), expected_percent(parts, Game::DrawOdds::TOTAL, locale) ] }
      assert_equal expected, rows, "the #{name} odds"
      assert_equal 100, rows.sum { |_, percent| shown_value(percent) }, "the #{name} odds sum to 100"
      assert_select "table[data-odds=#{name}] tbody svg.pixel-icon", odds.size
    end
  end

  def assert_rarity_shares(locale)
    shares = Catalog::RarityThresholds::SHARES
    basis = Catalog::RarityThresholds::BASIS
    common = Catalog::RarityThresholds::COMMON
    expected = Catalog::Rarity::TIERS.keys.sort.reverse.map do |tier|
      [ rarity_name(tier, locale), expected_percent(shares.fetch(tier) { basis - shares.values.sum }, basis, locale) ]
    end
    rows = rows_of("[data-rarity-shares] li")

    assert_equal expected, rows
    assert_equal shares.keys.sort.reverse + [ common ], css_select("[data-rarity-shares] li").map { Catalog::Rarity::TIERS.key(it["data-tier"].to_sym) }
    assert_equal 100, rows.sum { |_, percent| shown_value(percent) }
  end

  def assert_rarity_rule(locale)
    %w[rule score].each do |key|
      assert_select "section[aria-labelledby=how-it-works-rarity] p", I18n.t("pages.how_it_works.rarity.#{key}", locale:)
    end
  end

  def assert_numbers(locale)
    minutes = ->(count) { I18n.t("pages.how_it_works.minutes", count:, locale:) }
    reviews = ActiveSupport::NumberHelper.number_to_delimited(Steam::ReviewPolicy::MIN_REVIEWS, locale:)

    assert_select ".how-it-works__review-floor", /(?<![\d ,])#{Regexp.escape(reviews)}(?![\d ,])/
    assert_select ".how-it-works__pack-size", /\b#{Game::Pack::SIZE}\b/
    assert_select ".how-it-works__bank", /\b#{Game::Pack::BANK_SIZE}\b/
    assert_select ".how-it-works__interval", /\b#{Regexp.escape(minutes.(Game::Pack::INTERVAL.in_minutes.to_i))}/
    assert_select ".how-it-works__refill", /\b#{Regexp.escape(minutes.((Game::Pack::BANK_SIZE * Game::Pack::INTERVAL).in_minutes.to_i))}/
    assert_select ".how-it-works__bonus-size", /\b#{Game::Pack::BONUS_SIZE}\b/
    assert_select ".how-it-works__reward-size", /\b#{Game::Pack::SIZE}\b/
    assert_select ".how-it-works__reserve", /\b#{Game::Reserve::FULL}\b/
    assert_select ".how-it-works__themes", /\b#{Catalog::Themes.keys.size}\b/
    assert_select ".how-it-works__franchises", /\b#{Catalog::SetBuilder::MIN_GAMES}\b/
    assert_select ".how-it-works__studios",
      /#{Regexp.escape(ActiveSupport::NumberHelper.number_to_delimited(Catalog::SetBuilder::STUDIO_REVIEW_FLOOR, locale:))}/
    Catalog::Themes::TIER_PERCENTS.each_value do |percent|
      assert_select ".how-it-works__set-tiers", /#{Regexp.escape(expected_percent(percent, 100, locale))}/
    end
  end

  test "a visitor reads every section in French, its numbers those the game applies" do
    get how_it_works_path(locale: :fr)

    assert_response :success
    assert_select "html[lang=fr]"
    assert_select "title", /Comment ça marche/
    assert_select "main h1", "Comment ça marche"
    assert_equal FRENCH_HEADINGS, css_select("main section.how-it-works__section > h2").map { it.text.strip }
    css_select("main section.how-it-works__section").each do |section|
      assert_equal section["aria-labelledby"], section.at_css("h2")["id"]
    end
    assert_every_odds_table(:fr)
    assert_rarity_shares(:fr)
    assert_rarity_rule(:fr)
    assert_numbers(:fr)
    Catalog::HallOfFame.keys.each do |key|
      assert_select ".how-it-works__hall-of-fame li", /#{Regexp.escape(I18n.t("catalog.hall_of_fame.#{key}", locale: :fr))}/
    end
    assert_select ".how-it-works__ufos", /Les OVNI/
    assert_select "[style]", false
  end

  test "a player reads the same sections in English" do
    sign_in(accounts_players(:player))

    get how_it_works_path(locale: :en)

    assert_response :success
    assert_select "html[lang=en]"
    assert_select "main h1", "How it works"
    assert_equal ENGLISH_HEADINGS, css_select("main section.how-it-works__section > h2").map { it.text.strip }
    assert_every_odds_table(:en)
    assert_rarity_shares(:en)
    assert_rarity_rule(:en)
    assert_numbers(:en)
    assert_select "[style]", false
  end

  test "the day and week rules give the next day change and week start for the browser to show in its own time" do
    travel_to(Time.utc(2026, 10, 14, 10)) { get how_it_works_path(locale: :fr) }

    assert_select "p", "Une fois par jour, un booster offert vous attend sur le pont. Le jour change à 00:00 UTC."
    assert_select "p time[datetime='2026-10-15T00:00:00Z'][data-controller=local-time][data-local-time-style-value=time]" \
      "[data-local-time-suffix-value=', heure locale']", "00:00 UTC"
    assert_select "p time[datetime='2026-10-19T00:00:00Z'][data-controller=local-time][data-local-time-style-value=weekday-time]" \
      "[data-local-time-suffix-value=', heure locale']", "2026-10-19 00:00 UTC"
    assert_select "p", /\AChaque semaine, pendant sept jours à partir du 2026-10-19 00:00 UTC, tous les joueurs/
    assert_select "p", text: /heure locale/, count: 0
  end

  test "the screen sits under the PLUS tab, its phone back to PLUS" do
    get how_it_works_path(locale: :fr)

    assert_select "a.tab-bar__tab[href='/fr/more'][aria-current=page]", /Plus/
    assert_select "a.tab-bar__tab[href='/fr'][aria-current]", false
    assert_select ".top-bar a.top-bar__phone-back[href='/fr/more']", /Plus/
  end

  test "the screen renders the same with no published season" do
    get how_it_works_path(locale: :en)
    published = css_select("main").sole.to_html

    Catalog::Season.update_all(status: "draft", published_at: nil)
    get how_it_works_path(locale: :en)

    assert_response :success
    assert_equal published, css_select("main").sole.to_html
  end
end
