# Development only (its routes exist only there): signs in as a fake player
# without Steam or Clerk, then opens the starting screen.
#
#   http://localhost:3000/                      signed in as "Dev Player", on the starting screen
#   /dev/sign-in?as=3                           signed in as fake player 3 (see db/seeds.rb)
#   /dev/sign-in?to=/fr/collection              another screen, just this once
#
# The starting screen is DEV_START_PATH (set in compose.dev.yaml), the
# leaderboard by default. A player already signed in stays signed in.
class DevSignInsController < ApplicationController
  include OpensPlayerSession

  # Signing in writes, and this is a GET.
  skip_around_action :read_only_unless_writing

  DEFAULT_START_PATH = "/en/register".freeze
  PERSONA_NAMES = [ "Dev Player", "Ariadne", "Bastien", "Chloe", "Dimitri", "Elise", "Farid",
    "Gwen", "Hugo", "Ines", "Jules", "Katia" ].freeze

  FAKE_PLAYER_COUNT = 30

  def self.steam_id(number) = format("76561190000000%03d", number)
  def self.persona_name(number) = PERSONA_NAMES.fetch(number, "Fake Player #{number}")

  def show
    authorize :session, :create?
    raise ActionController::RoutingError, "Not Found" unless Rails.env.development?

    open_session_for(fake_player(Integer(params[:as], exception: false) || 0)) if params.key?(:as) || current_player.nil?
    redirect_to safe_origin_path(params[:to]) || start_path
  end

  private
    def fake_player(number)
      Accounts::SignIn.new.call(steam_id: self.class.steam_id(number), persona_name: self.class.persona_name(number)).value!
    end

    def start_path
      safe_origin_path(ENV["DEV_START_PATH"]) || DEFAULT_START_PATH
    end
end
