module ErrorPage
  UNSUPPORTED_BROWSER = "406-unsupported-browser"

  class << self
    def call(env)
      request = ActionDispatch::Request.new(env)
      # Rails has rewritten the path to the status by now; the locale is in the original one.
      original_path = request.get_header("action_dispatch.original_path") || request.path_info
      I18n.with_locale(locale(original_path, request.get_header("HTTP_ACCEPT_LANGUAGE"))) do
        ActionDispatch::PublicExceptions.new(Rails.public_path).call(env)
      end
    end

    def unsupported_browser_file(request)
      file(UNSUPPORTED_BROWSER, locale(request.path, request.get_header("HTTP_ACCEPT_LANGUAGE")))
    end

    def locale(path, accept_language)
      path_locale(path) || HttpAcceptLanguage::Parser.new(accept_language).compatible_language_from(I18n.available_locales) || I18n.default_locale
    end

    private
      def path_locale(path)
        segment = path.to_s.split("/").second
        I18n.available_locales.find { it.to_s == segment }
      end

      def file(name, locale)
        Rails.public_path.join("#{name}.#{locale}.html")
      end
  end
end
