require "test_helper"
require_relative "../../support/steam_sign_in"

module BackOffice
  class CreditDonorsControllerTest < ActionDispatch::IntegrationTest
    include SteamSignIn

    def sign_in_origin = "/fr"

    setup do
      @administrator = accounts_players(:administrator)
      @moderator = accounts_players(:moderator)
    end

    test "an administrator adds a donor, sees it listed and the credits page thanks it" do
      sign_in(@administrator)

      post back_office_credit_donors_path(locale: :fr), params: { name: "Sandrine K" }
      assert_redirected_to back_office_credit_donors_path(locale: :fr)
      follow_redirect!
      assert_select "li[data-credit-donor-token] .announcement-editor__status", "Sandrine K"

      get credits_path(locale: :fr)
      assert_select ".credits__donor", "Sandrine K"
    end

    test "the credits page shows no donors section while the list is empty" do
      get credits_path(locale: :fr)

      assert_select ".credits__donor", false
      assert_select "h2.legal__heading", text: "Donateurs", count: 0
    end

    test "an administrator removes a donor" do
      donor = Accounts::AddCreditDonor.new.call(staff: @administrator, name: "Sandrine K").value!
      sign_in(@administrator)

      delete back_office_credit_donor_path(locale: :fr, token: donor.token)

      assert_redirected_to back_office_credit_donors_path(locale: :fr)
      assert_empty Accounts::CreditDonors.names
    end

    test "a repeat comes back with the alert" do
      sign_in(@administrator)
      2.times { post back_office_credit_donors_path(locale: :fr), params: { name: "Sandrine K" } }

      assert_equal I18n.t("errors.accounts.credit_donor_already_listed", locale: :fr), flash[:alert]
    end

    test "a moderator is forbidden and nothing is written" do
      sign_in(@moderator)

      post back_office_credit_donors_path(locale: :fr), params: { name: "Sandrine K" }

      assert_response :forbidden
      assert_empty Accounts::CreditDonors.names
    end

    test "the dashboard links the tile for an administrator only" do
      sign_in(@administrator)
      get back_office_path(locale: :fr)
      assert_select "a[data-office-tile='credit-donors'][href='/fr/back-office/credit-donors']"

      delete session_path(locale: :fr)
      sign_in(@moderator)
      get back_office_path(locale: :fr)
      assert_select "a[data-office-tile='credit-donors']", false
    end
  end
end
