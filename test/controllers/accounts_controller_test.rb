require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  include GamePacks
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
  end

  test "the settings screen has the COMPTE row and the delete dialog, the button disabled by script only" do
    sign_in(@player)

    get settings_path(locale: :fr)

    assert_select ".settings-row__label", "Compte"
    assert_select "button.button--danger[aria-haspopup=dialog][data-dialog-opener-dialog-value=delete-dialog]", "Supprimer mon compte"
    assert_select "dialog#delete-dialog[aria-labelledby=delete-dialog-title]" do
      assert_select "#delete-dialog-title", "Supprimer mon compte"
      assert_select "form[action='/fr/account'][data-turbo=false][data-controller=confirm-word][data-confirm-word-word-value=SUPPRIMER]"
      assert_select "input[name=_method][value=delete]", visible: :all
      assert_select "label[for=delete-confirmation]", "Tapez SUPPRIMER pour confirmer"
      assert_select "input#delete-confirmation[name=confirmation][autocomplete=off]"
      assert_select "button[type=submit].button--danger:not([disabled])", "Supprimer définitivement"
      assert_select "button[type=button][data-action='dialog#close']", "Annuler"
    end

    get settings_path(locale: :en)
    assert_select "form[action='/en/account'][data-confirm-word-word-value=DELETE]"
    assert_select "label[for=delete-confirmation]", "Type DELETE to confirm"
  end

  test "a player banned while signed in cannot delete their own account" do
    sign_in(@player)
    @player.update!(banned_at: Time.current)

    delete account_path(locale: :en), params: { confirmation: "DELETE" }

    assert_not_predicate @player.reload, :deleted?
    assert_not_nil @player.steam_id
  end

  ERASED_OR_CANCELLED = {
    "accounts_players" => { fr: [ "votre identifiant Steam", "votre nom", "votre profil et son lien", "l'heure de votre dernière visite", "votre dernier export de données" ],
                            en: [ "your Steam id", "your name", "your profile and its link", "the time of your last visit", "your last data export" ] },
    "accounts_data_exports" => { fr: [ "votre dernier export de données" ], en: [ "your last data export" ] },
    "game_player_states" => { fr: [ "votre dernière activité" ], en: [ "your latest activity" ] },
    "game_holdings" => { fr: [ "votre collection" ], en: [ "your collection" ] },
    "game_showcase_entries" => { fr: [ "votre vitrine" ], en: [ "your showcase" ] },
    "game_set_tiers" => { fr: [ "vos paliers de sets" ], en: [ "your set tiers" ] },
    "game_achievement_unlocks" => { fr: [ "vos succès" ], en: [ "your achievements" ] },
    "game_packs" => { fr: [ "vos capsules, ouvertes ou non" ], en: [ "your capsules, opened or not" ] },
    "game_daily_bonus_claims" => { fr: [ "vos bonus du jour" ], en: [ "your daily bonuses" ] },
    "game_goal_rewards" => { fr: [ "vos récompenses de l'objectif communautaire" ], en: [ "your community goal rewards" ] },
    "game_friendships" => { fr: [ "vos amis" ], en: [ "your friends" ] },
    "game_invitations" => { fr: [ "vos invitations" ], en: [ "your invitations" ] },
    "game_friend_codes" => { fr: [ "votre code ami" ], en: [ "your friend code" ] },
    "game_feed_entries" => { fr: [ "vos entrées du fil d'activité : tirages, découvertes, reposts et tous les échanges qui vous nomment" ],
                             en: [ "your activity feed entries: pulls, discoveries, reposts and every trade that names you" ] },
    "game_trades" => { fr: [ "Vos échanges en cours seront annulés" ], en: [ "Your open trades will be cancelled" ] }
  }.freeze

  KEPT = {
    "game_trades" => { fr: [ "vos échanges passés" ], en: [ "your past trades" ] },
    "game_first_discoveries" => { fr: [ "vos premières découvertes" ], en: [ "your first discoveries" ] },
    "game_weekly_contributions" => { fr: [ "vos contributions à l'objectif communautaire" ], en: [ "your contributions to the community goal" ] },
    "accounts_reports" => { fr: [ "les signalements" ], en: [ "reports" ] },
    "accounts_moderation_actions" => { fr: [ "l'historique de modération" ], en: [ "the moderation history" ] },
    "event_store_events" => { fr: [ "le journal des actions du jeu" ], en: [ "the log of game actions" ] }
  }.freeze

  def tables_naming_a_player
    connection = ActiveRecord::Base.connection
    keyed = connection.tables.select { |table| connection.foreign_keys(table).any? { it.to_table == "accounts_players" } }
    keyed + [ "accounts_players", "event_store_events" ]
  end

  test "the delete dialog names what deletion does to every table that names a player, in both locales" do
    assert_equal tables_naming_a_player.sort, (ERASED_OR_CANCELLED.keys | KEPT.keys).sort
    sign_in(@player)

    %i[fr en].each do |locale|
      get settings_path(locale:)

      note = css_select("#delete-dialog-note").text
      kept = css_select("#delete-dialog-kept").text
      ERASED_OR_CANCELLED.each_value { |words| words[locale].each { assert_includes note, it } }
      assert_no_match(/complétés|completed sets/, note)
      KEPT.each_value do |words|
        words[locale].each do |phrase|
          assert_includes kept, phrase
          assert_not_includes note, phrase
        end
      end
      assert_select "dialog#delete-dialog input#delete-confirmation[aria-describedby='delete-dialog-note delete-dialog-kept']"
    end
  end

  [ "SUPPRIMER", "supprimer", "  Supprimer \n" ].each do |word|
    test "typing #{word.inspect} deletes the account, signs the player out and lands on the landing with a toast" do
      create_pack(@player)
      token = @player.token
      sign_in(@player)

      delete account_path(locale: :fr), params: { confirmation: word }

      assert_redirected_to home_path(locale: :fr)
      assert_response :see_other
      assert_nil session[:player_id]
      assert_predicate @player.reload, :deleted?
      assert_equal 0, Game::Pack.where(player_id: @player.id).count
      follow_redirect!
      assert_select ".landing-hero"
      assert_select ".toast", /Votre compte a été supprimé/

      get brother_path(token:, locale: :fr)
      assert_response :not_found
    end
  end

  test "the English word is DELETE, and the player's motion preference stays as a cookie" do
    @player.update!(reduced_motion: true)
    sign_in(@player)

    delete account_path(locale: :en), params: { confirmation: "delete" }

    assert_redirected_to home_path(locale: :en)
    assert_predicate @player.reload, :deleted?
    assert_equal "reduced", cookies[:motion]
    assert_equal "Your account has been deleted. Thank you for playing.", flash[:notice]
  end

  [ nil, "", "SUPPRIME", "SUPPRIMER DÉFINITIVEMENT", "DELETE", [ "SUPPRIMER" ] ].each do |word|
    test "#{word.inspect} is not the word: nothing is deleted, back to the settings with the reason" do
      create_pack(@player)
      sign_in(@player)

      delete account_path(locale: :fr), params: { confirmation: word }

      assert_redirected_to settings_path(locale: :fr)
      assert_equal "Tapez SUPPRIMER pour confirmer la suppression. Rien n'a été effacé.", flash[:alert]
      assert_not @player.reload.deleted?
      assert_equal 1, Game::Pack.where(player_id: @player.id).count
      assert session[:player_id]
    end
  end

  test "a visitor is sent to the landing; nothing is deleted" do
    delete account_path(locale: :en), params: { confirmation: "DELETE" }

    assert_redirected_to home_path(locale: :en)
    assert_nil flash[:alert]
    assert_not @player.reload.deleted?
  end

  test "another browser still signed in as the deleted player becomes a visitor" do
    sign_in(@player)
    other_browser = open_session
    other_browser.post "/auth/steam", params: { origin: "/en" }
    other_browser.follow_redirect!
    assert other_browser.session[:player_id]

    delete account_path(locale: :en), params: { confirmation: "DELETE" }

    other_browser.get settings_path(locale: :en)
    other_browser.assert_redirected_to home_path(locale: :en)
    assert_nil other_browser.session[:player_id]
    other_browser.delete account_path(locale: :en), params: { confirmation: "DELETE" }
    other_browser.assert_redirected_to home_path(locale: :en)
  end

  test "the Steam id signs in again as a new player" do
    steam_id = @player.steam_id
    sign_in(@player)
    delete account_path(locale: :en), params: { confirmation: "DELETE" }

    sign_in_new_player(steam_id)

    assert_not_equal @player.id, session[:player_id]
    assert_equal steam_id, Accounts::Player.find(session[:player_id]).steam_id
  end
end
