require "test_helper"

class Steam::SignInIdentityTest < ActiveSupport::TestCase
  def auth(uid, provider: "steam")
    OmniAuth::AuthHash.new(provider: provider, uid: uid)
  end

  test "a Steam claimed id gives its 17-digit Steam id" do
    result = Steam::SignInIdentity.steam_id_from(auth("https://steamcommunity.com/openid/id/76561197960287930"))

    assert result.success?
    assert_equal "76561197960287930", result.value!
  end

  [
    "https://evil.example/openid/id/123",
    "https://evil.example/openid/id/76561197960287930",
    "http://steamcommunity.com/openid/id/76561197960287930",
    "https://steamcommunity.com/openid/id/7656119796028793",
    "https://steamcommunity.com/openid/id/765611979602879300",
    "https://steamcommunity.com/openid/id/76561197960287930/",
    "https://steamcommunity.com/openid/id/76561197960287930?x=1",
    "https://steamcommunity.com.evil.example/openid/id/76561197960287930",
    "https://steamcommunity.com/openid/id/76561197960287930\nhttps://evil.example",
    "",
    nil
  ].each do |uid|
    test "the claimed id #{uid.inspect} is refused" do
      result = Steam::SignInIdentity.steam_id_from(auth(uid))

      assert result.failure?
      assert_equal :invalid_claimed_id, result.failure
    end
  end

  test "an auth hash from another provider is refused" do
    result = Steam::SignInIdentity.steam_id_from(auth("https://steamcommunity.com/openid/id/76561197960287930", provider: "open_id"))

    assert_equal :invalid_claimed_id, result.failure
  end

  test "a missing auth hash is refused" do
    assert_equal :invalid_claimed_id, Steam::SignInIdentity.steam_id_from(nil).failure
  end

  test "every failure code has a message in both locales" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) { assert_predicate I18n.t(Steam::SignInIdentity.failure_key(:invalid_claimed_id)), :present? }
    end
  end
end
