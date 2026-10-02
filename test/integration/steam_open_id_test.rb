require "test_helper"

# The real OmniAuth OpenID flow against a stand-in for Steam: the request
# phase, then a positive assertion through ruby-openid's discovery,
# return_to and check_authentication code. OmniAuth test mode skips all of
# that; this test is what catches ruby-openid breaking on a Ruby upgrade.
class SteamOpenIdTest < ActionDispatch::IntegrationTest
  STEAM_ID = "76561197960287930".freeze
  CLAIMED_ID = "https://steamcommunity.com/openid/id/#{STEAM_ID}".freeze
  LOGIN = "https://steamcommunity.com/openid/login".freeze

  # Answers ruby-openid's HTTP calls the way Steam does.
  class FakeSteam
    Response = Struct.new(:code, :body, :headers) do
      def [](name) = headers[name.downcase]
    end

    attr_reader :requests

    def initialize(valid: true)
      @valid = valid
      @requests = []
    end

    def fetch(url, body = nil, _headers = nil, _redirect_limit = nil)
      @requests << url
      response = body ? check_authentication : xrds(url.include?("/openid/id/") ? "signon" : "server")
      OpenID::HTTPResponse._from_net_response(response, url)
    end

    private
      def xrds(type)
        Response.new("200", <<~XML, { "content-type" => "application/xrds+xml" })
          <?xml version="1.0" encoding="UTF-8"?>
          <xrds:XRDS xmlns:xrds="xri://$xrds" xmlns="xri://$xrd*($v*2.0)">
            <XRD><Service priority="0"><Type>http://specs.openid.net/auth/2.0/#{type}</Type><URI>#{LOGIN}</URI></Service></XRD>
          </xrds:XRDS>
        XML
      end

      def check_authentication
        Response.new("200", "ns:http://specs.openid.net/auth/2.0\nis_valid:#{@valid}\n", { "content-type" => "text/plain" })
      end
  end

  setup do
    @fetcher = OpenID.fetcher
    # Production checks authenticity tokens; the test environment does not.
    @forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    OpenID.fetcher = @fetcher
    ActionController::Base.allow_forgery_protection = @forgery_protection
  end

  def steam_answers(valid: true)
    OpenID.fetcher = FakeSteam.new(valid: valid)
  end

  # The positive assertion Steam sends back to the return_to URL.
  def assertion_params(return_to)
    {
      "openid.ns" => "http://specs.openid.net/auth/2.0",
      "openid.mode" => "id_res",
      "openid.op_endpoint" => LOGIN,
      "openid.claimed_id" => CLAIMED_ID,
      "openid.identity" => CLAIMED_ID,
      "openid.return_to" => return_to,
      "openid.response_nonce" => "#{Time.now.utc.iso8601}#{SecureRandom.hex(4)}",
      "openid.assoc_handle" => "1234567890",
      "openid.signed" => "signed,op_endpoint,claimed_id,identity,return_to,response_nonce,assoc_handle",
      "openid.sig" => "c2lnbmF0dXJl"
    }
  end

  def start_sign_in
    get "/en"
    token = css_select("form[action='/auth/steam'] input[name=authenticity_token]").first["value"]
    post "/auth/steam", params: { origin: "/en", authenticity_token: token }
    assert_response :redirect
    location = URI(response.location)
    assert_equal LOGIN, "#{location.scheme}://#{location.host}#{location.path}"
    Rack::Utils.parse_query(location.query).fetch("openid.return_to")
  end

  test "a positive assertion verified by Steam signs the player in" do
    steam_answers(valid: true)
    return_to = start_sign_in

    get URI(return_to).request_uri, params: assertion_params(return_to)

    player = Accounts::Player.find_by!(steam_id: STEAM_ID)
    assert_equal player.id, session[:player_id]
    assert_redirected_to "/en"
    assert_includes OpenID.fetcher.requests, LOGIN
  end

  test "an assertion Steam does not confirm is refused" do
    steam_answers(valid: false)
    return_to = start_sign_in

    get URI(return_to).request_uri, params: assertion_params(return_to)
    follow_redirect! while response.redirect? && response.location.include?("/auth/")

    assert_nil session[:player_id]
    assert_nil Accounts::Player.find_by(steam_id: STEAM_ID)
  end
end
