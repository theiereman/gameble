require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"

class MarketEntrustSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include Holdings
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @common = catalog_card_seasons(:common_card_one)
    @uncommon = catalog_card_seasons(:uncommon_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    @legendary = catalog_card_seasons(:legendary_card_one)
    Game::Market::Settings.delete_all
  end

  def sign_in_through_the_site
    mock_steam_sign_in(@player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def cell(card_season) = find(".entrust-cell[data-ref='#{card_season.card.slug}:#{card_season.season.number}']")

  def tick(card_season) = cell(card_season).find(".entrust-cell__toggle").click

  def raise_copies(card_season) = cell(card_season).find(".stepper__button--more").click

  def assert_total(text) = assert_selector(".entrust-recap__total .picoin-amount__figure", text:)

  def show_single_copies = find(".copy-filters .filter-chip__text", text: /doubles/i).click

  test "a player ticks two editions, raises one and sees the total minted, and the collection holds fewer copies" do
    open_market!
    hold(@player, @common.id, 2)
    hold(@player, @rare.id, 2)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)
    tick(@common)
    tick(@rare)
    raise_copies(@common)
    assert_total "7,000"
    click_on "Entrust 3 copies"

    assert_selector ".entrust-result__minted .picoin-amount[aria-label='7,000 PiCoins']"
    assert_selector ".entrust-result__minted .picoin-amount__figure", text: "7,000"
    assert_selector ".entrust-result__copies", text: "3 copies entrusted"
    assert_equal 1, Game::Holding.where(player_id: @player.id).sum(:quantity)
  end

  test "validating stays on the screen: the result shows the minted amount, the grid and gauge follow, and the player entrusts again" do
    open_market!
    hold(@player, @common.id, 3)
    hold(@player, @rare.id, 3)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)
    tick(@common)
    click_on "Entrust 1 copy"

    assert_selector ".entrust-result__minted .picoin-amount__figure", text: "1,000"
    assert_selector "#entrust-result-heading:focus"
    assert_selector ".entrust-cell[data-ref*='#{@common.card.slug}'] .entrust-cell__free", text: "2 free copies"
    assert_no_selector ".entrust-cell--picked"
    assert_selector ".entrust-recap__cap-text", text: "1,000 of 1,200,000 today"
    assert_selector ".entrust-recap__cap .gauge:not([data-growing])"
    assert_current_path new_market_entrustment_path(locale: :en)

    tick(@rare)
    assert_no_selector ".entrust-result"
    click_on "Entrust 1 copy"

    assert_selector ".entrust-result__minted .picoin-amount__figure", text: "5,000"
    assert_selector ".entrust-recap__cap-text", text: "6,000 of 1,200,000 today"
    assert_equal 2, Game::Holding.find_by(player_id: @player.id, card_season_id: @common.id).quantity
    assert_equal 2, Game::Holding.find_by(player_id: @player.id, card_season_id: @rare.id).quantity
  end

  test "the desktop flow previews the batch as the player filters and ticks, names the copy over the cap and validates" do
    settings = open_market!
    hold(@player, @legendary.id, 1)
    hold(@player, @uncommon.id, 2)
    hold(@player, @common.id, 3)
    Game::Market::Mint.credit(player_id: @player.id, amount: 1_150_000, settings_id: settings.id)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)
    assert_no_selector ".entrust-cell", text: "Golden Crown"
    show_single_copies
    fill_in "entrust-search", with: "crown"
    assert_selector ".entrust-cell:not([hidden])", count: 1
    tick(@legendary)
    fill_in "entrust-search", with: ""
    assert_selector ".entrust-cell:not([hidden])", count: 3
    tick(@uncommon)
    tick(@common)
    assert_selector ".entrust-recap__line:first-child[data-state=stays]", text: "Golden Crown"
    assert_selector ".entrust-recap__over", text: /Golden Crown/
    assert_total "3,000"

    raise_copies(@uncommon)

    assert_total "5,000"
    assert_selector "button[type=submit]", text: /entrust 3 copies/i
    click_on "Entrust 3 copies"

    assert_selector ".entrust-result__minted .picoin-amount__figure", text: "5,000"
    assert_selector "[role=status] .entrust-result__stayed-line .picoin-amount[aria-label='100,000 PiCoins']"
    assert_selector ".entrust-result__stayed-cap", text: "50,000"
    assert_selector ".entrust-cell[data-ref*='#{@legendary.card.slug}']:not(.entrust-cell--picked)"
    assert_equal 1, Game::Holding.find_by(player_id: @player.id, card_season_id: @legendary.id).quantity
  end

  test "the stepper reaches every free copy and an only copy ticks without one" do
    open_market!
    hold(@player, @rare.id, 3)
    hold(@player, @common.id, 1)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)
    show_single_copies
    tick(@common)
    assert_selector ".entrust-cell--picked", count: 1
    assert_no_selector ".entrust-cell[data-ref*='#{@common.card.slug}'] .stepper"
    tick(@rare)
    2.times { raise_copies(@rare) }

    assert_selector ".entrust-cell[data-ref*='#{@rare.card.slug}'] .stepper__value", text: "×3"
    assert_selector ".entrust-cell[data-ref*='#{@rare.card.slug}'] .stepper__button--more[disabled]"
    assert_total "16,000"
  end

  test "the keys move between cells and change the copies of a ticked cell" do
    open_market!
    hold(@player, @rare.id, 3)
    hold(@player, @common.id, 2)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)
    cell(@rare).find(".entrust-cell__toggle").send_keys(:space)
    assert_selector ".entrust-cell--picked", count: 1
    cell(@rare).find(".entrust-cell__toggle").send_keys("+", "+")
    assert_selector ".entrust-cell[data-ref*='#{@rare.card.slug}'] .stepper__value", text: "×3"
    cell(@rare).find(".entrust-cell__toggle").send_keys(:subtract)
    assert_selector ".entrust-cell[data-ref*='#{@rare.card.slug}'] .stepper__value", text: "×2"
    cell(@rare).find(".entrust-cell__toggle").send_keys(:arrow_right)
    assert_selector ".entrust-cell[data-ref*='#{@common.card.slug}'] .entrust-cell__toggle[tabindex='0']"
    assert_selector ".entrust-cell__toggle[tabindex='0']", count: 1
    cell(@common).find(".entrust-cell__toggle").send_keys("+")
    assert_selector ".entrust-cell--picked", count: 1
  end

  test "a full cap disables validation and says when it renews" do
    settings = open_market!
    hold(@player, @common.id, 2)
    Game::Market::Mint.credit(player_id: @player.id, amount: 1_200_000, settings_id: settings.id)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)
    tick(@common)

    assert_selector ".entrust-recap__full", text: "Your daily cap is reached. It renews at 00:00 UTC."
    assert_button "Entrust", disabled: true
  end

  test "nothing ticked prompts to choose and validation is disabled" do
    open_market!
    hold(@player, @common.id, 2)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)

    assert_selector ".entrust-recap__prompt", text: "Tick the cards to entrust."
    assert_button "Entrust", disabled: true
  end

  test "the filters with no match say so and offer to clear them" do
    open_market!
    hold(@player, @common.id, 2)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)
    fill_in "entrust-search", with: "zzzz"
    assert_selector ".entrust-grid__empty", text: "No edition matches these filters."
    within(".entrust-grid__empty") { click_on "Clear filters" }

    assert_selector ".entrust-cell:not([hidden])", count: 1
    assert_no_selector ".entrust-grid__empty"
  end

  test "a ticked cell that a filter hides stays ticked and in the recap" do
    open_market!
    hold(@player, @common.id, 2)
    hold(@player, @rare.id, 2)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)
    tick(@common)
    fill_in "entrust-search", with: "blue"

    assert_selector ".entrust-cell:not([hidden])", count: 1
    assert_selector ".entrust-recap__line", text: "Tin Soldier"
    assert_selector "input[name=selection][value='#{@common.card.slug}:#{@common.season.number}=1']", visible: :all
  end

  test "the sentence and the note describe the button, the status speaks after the selection rests, and Esc changes nothing" do
    open_market!
    hold(@player, @common.id, 2)
    hold(@player, @rare.id, 2)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)
    assert_selector "#entrust-not-returned", text: "Entrusted cards are not given back."
    assert_equal "", find("aside [data-entrust-recap-target=status][role=status][aria-live=polite]", visible: :all).text(:all)

    tick(@common)
    assert_selector "button[type=submit][aria-describedby='entrust-not-returned']"
    tick(@rare)
    assert_selector "button[type=submit][aria-describedby='entrust-not-returned entrust-rare-note']"
    assert_selector "#entrust-rare-note", text: /Rare or better/
    assert_selector "aside [data-entrust-recap-target=status][role=status][aria-live=polite]", text: "2 copies, 6,000 PiCoins", visible: :all

    fill_in "entrust-search", with: "blue"
    find("#entrust-search").send_keys(:escape)

    assert_selector ".entrust-cell", count: 1
    assert_equal "blue", find("#entrust-search").value
    assert_selector ".entrust-cell--picked", count: 1
    assert_selector ".entrust-recap__line", count: 2
    assert_current_path new_market_entrustment_path(locale: :en), ignore_query: true
  end

  test "settings changed behind the open form are refused inline, the new amounts are drawn and the ticks are kept" do
    open_market!
    hold(@player, @common.id, 2)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)
    tick(@common)
    open_market!(entrustment_common: 1_500)
    click_on "Entrust 1 copy"

    assert_selector ".market-entrust__refusal", text: /amounts changed/i
    assert_selector ".entrust-cell__value .picoin-amount[aria-label='1,500 PiCoins']"
    assert_selector ".entrust-cell--picked", count: 1
    assert_total "1,500"
    assert_equal 0, Game::Market::LedgerEntry.where(player_id: @player.id).count
    assert_equal 2, Game::Holding.find_by(player_id: @player.id, card_season_id: @common.id).quantity
  end

  test "with no free copy the screen offers to open a capsule" do
    open_market!
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)

    assert_selector ".market-entrust__notice", text: "No card to entrust."
    assert_link "Open capsules"
  end

  test "while the market is closed the page opens and validation is disabled" do
    Game::Market::CreateFirstSettings.new.call.value!
    hold(@player, @common.id, 2)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)
    tick(@common)

    assert_selector ".market-entrust__notice", text: "closed"
    assert_button "Entrust 1 copy", disabled: true
  end

  test "on a phone Confier ticks in three columns, sets copies in the sheet and validates from it" do
    open_market!
    hold(@player, @common.id, 2)
    hold(@player, @rare.id, 1)
    sign_in_through_the_site
    resize_to 390, 844

    visit new_market_entrustment_path(locale: :en)
    assert_selector "form#entrust[data-layout=phone]"
    assert_no_selector ".entrust-cell .stepper", visible: :visible
    assert_equal 3, find(".entrust-grid__list").style("grid-template-columns")["grid-template-columns"].split.size
    show_single_copies
    tick(@common)
    tick(@rare)
    assert_selector ".entrust-bar .entrust-bar__count", text: "2 copies"
    assert_selector ".entrust-bar .picoin-amount__figure", text: "6,000"

    click_on "Entrust ▸"
    assert_selector "dialog#entrust-recap-sheet[open] .entrust-recap__line", count: 2
    eventually("the sheet should be done rising") { evaluate_script("document.querySelector('#entrust-recap-sheet').getAnimations({ subtree: true }).length === 0") }
    stepper = find("dialog[open] .entrust-recap__line .stepper__button--more")
    assert_operator stepper.native.size.width, :>=, 44
    stepper.click
    assert_selector "dialog[open] .entrust-recap__total .picoin-amount__figure", text: "7,000"
    assert_selector ".entrust-bar .picoin-amount__figure", text: "7,000", visible: :all

    within("dialog[open]") { click_on "Entrust 3 copies" }

    assert_no_selector "dialog[open]"
    assert_selector ".entrust-result__minted .picoin-amount__figure", text: "7,000"
    assert_selector ".market-entrust__notice", text: "No card to entrust."
    assert_equal 0, Game::Holding.where(player_id: @player.id).sum(:quantity)
  end

  test "on a phone a refusal shows above the grid with the sheet closed" do
    open_market!
    hold(@player, @common.id, 2)
    sign_in_through_the_site
    resize_to 390, 844

    visit new_market_entrustment_path(locale: :en)
    tick(@common)
    open_market!(entrustment_common: 1_500)
    click_on "Entrust ▸"
    within("dialog[open]") { click_on "Entrust 1 copy" }

    assert_no_selector "dialog[open]"
    assert_selector "form#entrust > .market-entrust__refusal[role=alert]", text: /amounts changed/i
    assert_no_selector "dialog .market-entrust__refusal", visible: :all
    assert_selector ".entrust-cell--picked", count: 1
  end

  def second_edition_of(card_season)
    season = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    rows = [ { card_id: card_season.card_id, season_id: season.id, prestige_score: 0.5, rating: 50, rarity: card_season.rarity, number: 1 } ]
    Catalog::CardSeason.find(Catalog::CardSeason.insert_all!(rows, returning: :id).rows.flatten.sole)
  end

  test "from a card detail with two free editions the player reaches Confier on that card with doubles off and nothing ticked" do
    open_market!(first_opened_at: 1.day.ago)
    second = second_edition_of(@rare)
    hold(@player, @rare.id, 1)
    hold(@player, second.id, 1)
    hold(@player, @common.id, 3)
    sign_in_through_the_site

    visit card_path(locale: :en, slug: @rare.card.slug)
    click_on "Entrust"

    assert_selector ".entrust-cell", count: 2
    assert_no_selector ".entrust-cell--picked"
    assert_unchecked_field "Doubles", visible: :all
    assert_selector ".market-entrust__card-only"
  end

  test "from a card detail with one free edition Confier opens with it ticked" do
    open_market!(first_opened_at: 1.day.ago)
    hold(@player, @rare.id, 2)
    sign_in_through_the_site

    visit card_path(locale: :en, slug: @rare.card.slug)
    click_on "Entrust"

    assert_selector ".entrust-cell", count: 1
    assert_selector ".entrust-cell--picked", count: 1
    assert_unchecked_field "Doubles", visible: :all
  end

  test "the balance chip follows an entrustment and is absent before the opening and for a visitor" do
    open_market!(first_opened_at: Time.current)
    hold(@player, @rare.id, 2)
    sign_in_through_the_site

    assert_selector ".balance-chip--bar .balance-chip__available[aria-label='0 PiCoins']"
    visit new_market_entrustment_path(locale: :en)
    tick(@rare)
    click_on "Entrust 1 copy"

    assert_selector ".balance-chip--bar .balance-chip__available[aria-label='5,000 PiCoins']"
    assert_selector ".balance-chip--bar .balance-chip__committed .visually-hidden", text: "0 committed", visible: :all

    forget_market!
    open_market!
    visit home_path(locale: :en)
    assert_no_selector ".balance-chip"

    Capybara.reset_sessions!
    open_market!(first_opened_at: Time.current)
    visit home_path(locale: :en)
    assert_no_selector ".balance-chip"
  end

  def editions_of(card_season, count)
    seasons = Catalog::Season.insert_all!((2..count + 1).map { { status: :published, number: it, published_at: Time.current } }, returning: :id).rows.flatten
    rows = seasons.each_with_index.map { |season_id, index| { card_id: card_season.card_id, season_id:, prestige_score: 0.5, rating: 50, rarity: card_season.rarity, number: index + 1 } }
    Catalog::CardSeason.insert_all!(rows, returning: :id).rows.flatten.each { hold(@player, it, 2) }
  end

  test "the grid loads sixty cards, appends the next page near its end, and a ticked card keeps its tick across pages" do
    open_market!
    hold(@player, @rare.id, 2)
    editions_of(@common, 60)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)
    assert_selector ".entrust-cell", count: 60
    tick(@rare)
    assert_no_selector ".entrust-cell .card[data-controller~=tilt]"
    execute_script("document.querySelector('#entrust-pages').scrollIntoView()")

    assert_selector ".entrust-cell", count: 61
    assert_selector ".entrust-cell--picked", count: 1
    assert_total "5,000"
  end

  test "select all ticks every edition the filters keep, loaded or not, and the recap names the first ones" do
    open_market!
    hold(@player, @rare.id, 2)
    editions_of(@common, 60)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)
    tick(@rare)
    raise_copies(@rare)
    click_on "Select all (61)"

    assert_selector ".entrust-recap__more", text: "and 31 more"
    assert_selector ".entrust-recap__line", count: 30
    assert_selector "input[name=selection][value^='#{@rare.card.slug}:#{@rare.season.number}=2,']", visible: :all
    assert_equal 61, find("input[name=selection]", visible: :all).value.split(",").size
    assert_total "70,000"
  end

  test "the recap dock draws over the stepper of a ticked card scrolled under it" do
    open_market!
    editions_of(@common, 30)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)
    find_all(".entrust-cell__toggle").last.click
    assert_selector ".entrust-cell--picked .stepper", visible: :visible
    under_the_dock = evaluate_script(<<~JS)
      (() => {
        const stepper = document.querySelector(".entrust-cell--picked .stepper")
        const dock = document.querySelector(".market-entrust__dock")
        window.scrollBy(0, stepper.getBoundingClientRect().top - dock.getBoundingClientRect().top - 4)
        const box = stepper.getBoundingClientRect()
        return document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2)?.closest(".market-entrust__dock") !== null
      })()
    JS
    assert under_the_dock
  end
end
