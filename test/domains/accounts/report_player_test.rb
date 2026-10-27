require "test_helper"

class Accounts::ReportPlayerTest < ActiveSupport::TestCase
  setup do
    @reporter = accounts_players(:player)
    @reported = accounts_players(:moderator)
  end

  def report(reason = "cheating", reporter: @reporter, reported: @reported)
    Accounts::ReportPlayer.new.call(reporter:, reported:, reason:)
  end

  def player_with_steam_id(number)
    Accounts::Player.create!(steam_id: "7656119796030#{number.to_s.rjust(4, "0")}")
  end

  test "it stores one report per reason, naming the reporter and the reported" do
    Accounts::Report.reasons.each_key do |reason|
      reported = player_with_steam_id(Accounts::Report.count + 1)
      result = report(reason, reported:)

      assert result.success?
      assert_equal [ @reporter, reported, reason ], result.value!.then { |r| [ r.reporter, r.reported, r.reason ] }
    end
    assert_equal 4, Accounts::Report.count
  end

  [ nil, "", "spam", "Cheating", 1, [ "cheating" ] ].each do |reason|
    test "#{reason.inspect} is refused and stores nothing" do
      assert_equal Dry::Monads::Failure(:invalid_reason), report(reason)
      assert_equal 0, Accounts::Report.count
    end
  end

  test "a report of oneself, of nobody or by nobody is refused" do
    assert_equal Dry::Monads::Failure(:cannot_report_self), report(reported: @reporter)
    assert_equal Dry::Monads::Failure(:player_not_found), report(reported: nil)
    assert_equal Dry::Monads::Failure(:player_not_found), report(reported: Accounts::Player.new)
    assert_equal Dry::Monads::Failure(:player_required), report(reporter: nil)
    assert_equal Dry::Monads::Failure(:player_required), report(reporter: accounts_players(:banned))
    assert_equal 0, Accounts::Report.count
  end

  test "a repeat succeeds and adds nothing, keeping the first reason" do
    first = report("cheating").value!

    assert_no_difference "Accounts::Report.count" do
      assert_equal first, report("harassment").value!
    end
    assert_equal "cheating", first.reload.reason
  end

  test "a player reports at most five players a day" do
    Accounts::ReportPlayer::LIMIT.times { |n| assert report(reported: player_with_steam_id(n + 10)).success? }
    sixth = player_with_steam_id(99)

    assert_equal Dry::Monads::Failure(:rate_limited), report(reported: sixth)
    assert_equal Accounts::ReportPlayer::LIMIT, Accounts::Report.count

    # A repeat of a report already made still answers the same.
    assert report(reported: Accounts::Report.first.reported).success?

    travel 25.hours do
      assert report(reported: sixth).success?
    end
  end

  test "the limit is per reporter" do
    Accounts::ReportPlayer::LIMIT.times { |n| report(reported: player_with_steam_id(n + 10)) }

    assert report(reporter: accounts_players(:administrator)).success?
  end

  test "the database refuses a reason the enum does not know" do
    report
    assert_raises(ActiveRecord::StatementInvalid) { Accounts::Report.first.update_column(:reason, "spam") }
  end

  test "a failure has a message in both locales" do
    %i[invalid_reason player_not_found cannot_report_self rate_limited].each do |code|
      %i[fr en].each do |locale|
        I18n.with_locale(locale) { assert_predicate Accounts::ReportPlayer.failure_message(code), :present?, "#{code} #{locale}" }
      end
    end
  end
end
