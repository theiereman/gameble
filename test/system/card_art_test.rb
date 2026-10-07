require "application_system_test_case"

# The card art through pixelcrush (AD-17): filtered in the card-art worker with
# 32 colours, Steam's grey placeholder counted as missing, a CORS refusal
# drawn on the main thread without palette. The back-office card preview is
# the host page; card-art elements are added to it by script.
class CardArtTest < ApplicationSystemTestCase
  SAMPLE_CARD = "[data-specimen=common-s] .card__art".freeze

  # Adds one card-art element per URL, at the small art size, pinned to the
  # top of the window so each nears the viewport at once.
  ADD_ARTS = <<~JS.freeze
    (urls) => {
      const host = document.createElement("div")
      host.style.cssText = "position: fixed; inset: 0 auto auto 0; z-index: 1000; display: flex; flex-wrap: wrap"
      urls.forEach((url, index) => {
        const art = document.createElement("span")
        art.style.display = "inline-block"
        art.dataset.testArt = index
        art.dataset.controller = "card-art"
        art.dataset.cardArtUrlValue = url
        art.dataset.cardArtWidthValue = 68
        art.dataset.cardArtHeightValue = 108
        const canvas = document.createElement("canvas")
        canvas.width = 68
        canvas.height = 108
        canvas.dataset.cardArtTarget = "canvas"
        art.append(canvas)
        host.append(art)
      })
      document.body.append(host)
    }
  JS

  setup do
    OmniAuth.config.test_mode = true
    administrator = accounts_players(:administrator)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{administrator.steam_id}")
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit back_office_cards_path(locale: :en)
    assert_selector SAMPLE_CARD, visible: :all
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sample_path
    find(SAMPLE_CARD, visible: :all)["data-card-art-url-value"]
  end

  def add_arts(urls)
    page.execute_script("(#{ADD_ARTS})(#{urls.to_json})")
  end

  test "thirty covers are filtered in the worker, each in at most 32 colours" do
    urls = (1..30).map { |n| "#{sample_path}?copy=#{n}" }
    add_arts(urls)

    assert_selector "[data-test-art][data-art=drawn] canvas:not([hidden])", count: 30, visible: :all
    colors = page.evaluate_script(<<~JS)
      [...document.querySelectorAll("[data-test-art] canvas")].map((canvas) => {
        const data = canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height).data
        const colors = new Set()
        for (let offset = 0; offset < data.length; offset += 4) {
          if (data[offset + 3] !== 0) colors.add(`${data[offset]},${data[offset + 1]},${data[offset + 2]}`)
        }
        return colors.size
      })
    JS
    assert_equal 30, colors.size
    assert colors.all? { |count| count.between?(2, 32) }, "each canvas should hold 2 to 32 colours: #{colors}"

    # The window never fetched them: the worker did.
    fetched = page.evaluate_script(<<~JS)
      ((urls) => {
        const names = new Set(performance.getEntriesByType("resource").map((entry) => entry.name))
        return urls.filter((url) => names.has(new URL(url, location.href).href))
      })(#{urls.to_json})
    JS
    assert_empty fetched
  end

  test "Steam's grey placeholder counts as missing" do
    grey = page.evaluate_script(<<~JS)
      (() => {
        const canvas = document.createElement("canvas")
        canvas.width = 300
        canvas.height = 450
        const context = canvas.getContext("2d")
        context.fillStyle = "rgb(128, 128, 128)"
        context.fillRect(0, 0, 300, 450)
        return canvas.toDataURL("image/png")
      })()
    JS
    add_arts([ grey ])

    assert_selector "[data-test-art][data-art=failed]", visible: :all
    assert_selector "[data-test-art] canvas", visible: :hidden
  end

  test "a cover refused by CORS is drawn on the main thread without palette" do
    port = Capybara.current_session.server.port
    add_arts([ "http://localhost:#{port}#{sample_path}" ])

    assert_selector "[data-test-art][data-art=plain] canvas:not([hidden])", visible: :all
  end
end
