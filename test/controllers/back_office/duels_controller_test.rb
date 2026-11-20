require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/steam_sign_in"
require_relative "../../support/balance_duels"

module BackOffice
  # How duels play per rules version, staff only: live duels by deck recipe apart from practice duels by bot archetype.
  class DuelsControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include SteamSignIn
    include BalanceDuels

    def written_statements(&request)
      statements = []
      record = ->(*, payload) { statements << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)\b/i) }
      ActiveSupport::Notifications.subscribed(record, "sql.active_record", &request)
      statements
    end

    def figure(row, name) = css_select("#{row} [data-duel-figure=#{name}]").map { it.text.strip }

    def calls(scope, call) = css_select("[data-duel-stats=#{scope}] [data-duel-call=#{call}] td").last.text.strip

    def selected_version = css_select("#duel-version option[selected]").map { it["value"] }

    test "a moderator reads the current rules' live figures, recipes and calls apart from the practice duels, without a write" do
      play_balance_duels
      sign_in(accounts_players(:moderator))

      written = written_statements { get back_office_duels_path(locale: :en) }

      assert_response :success
      assert_empty written
      assert_select "h1", "How duels play"
      assert_select "[style]", false
      assert_equal [ Game::DuelRules::VERSION.to_s ], selected_version
      live = "[data-duel-figures=live]"
      assert_equal [ "4", "1", "33%", "33%", "33%" ],
        %w[finished forfeited first_caller_wins decided_on_margin with_automatic_move].flat_map { figure(live, it) }
      assert_equal %w[coverage popularity rating other], css_select("[data-duel-recipe]").map { it["data-duel-recipe"] }
      assert_equal [ "2", "1", "50%" ], %w[decks wins win_rate].flat_map { figure("[data-duel-recipe=rating]", it) }
      assert_equal [ "1", "1", "100%" ], %w[decks wins win_rate].flat_map { figure("[data-duel-recipe=coverage]", it) }
      assert_equal [ "2", "0" ], [ calls("live", "rating-high"), calls("live", "circulation-high") ]
      assert_equal %w[rating other], css_select("[data-duel-practice]").map { it["data-duel-practice"] }
      assert_equal [ "2", "50%" ], %w[finished bot_wins].flat_map { figure("[data-duel-practice=rating]", it) }
      assert_equal [ "1", "0%" ], %w[finished bot_wins].flat_map { figure("[data-duel-practice=other]", it) }
      assert_equal "2", calls("practice", "popularity-high")
      assert_select "[data-duel-recipe=trumps]", false
    end

    test "the previous rules show their own figures, the version kept in the select" do
      play_balance_duels
      sign_in(accounts_players(:moderator))

      get back_office_duels_path(locale: :en, version: Game::DuelRules::VERSION - 1)

      assert_equal [ (Game::DuelRules::VERSION - 1).to_s ], selected_version
      assert_equal [ "1", "0", "100%" ],
        %w[finished forfeited first_caller_wins].flat_map { figure("[data-duel-figures=live]", it) }
      assert_equal %w[other], css_select("[data-duel-recipe]").map { it["data-duel-recipe"] }
      assert_select "[data-duel-empty=practice]"
      assert_select "[data-duel-practice]", false
    end

    test "a version that is not a number or has no finished duel falls back to the current rules" do
      sign_in(accounts_players(:moderator))

      [ "abc", "999" ].each do |version|
        get back_office_duels_path(locale: :en, version:)

        assert_response :success
        assert_equal [ Game::DuelRules::VERSION.to_s ], selected_version, version
        assert_select "[data-duel-empty=live]"
        assert_select "[data-duel-empty=practice]"
      end
    end

    test "the back-office home links to it for a moderator" do
      sign_in(accounts_players(:moderator))

      get back_office_path(locale: :en)

      assert_select "a.office-tile[data-office-tile=duels][href='/en/back-office/duels'] svg.pixel-icon"
    end

    test "a player does not find it" do
      sign_in(accounts_players(:player))

      get back_office_duels_path(locale: :en)

      assert_unknown_address
    end
  end
end
