module LegalSettings
  VARIABLES = {
    contact_email: "LEGAL_CONTACT_EMAIL",
    host_name: "LEGAL_HOST_NAME",
    host_address: "LEGAL_HOST_ADDRESS"
  }.freeze

  DEVELOPMENT_VALUES = {
    contact_email: "contact@example.test",
    host_name: "Example Hosting",
    host_address: "1 rue de l'Exemple, 75000 Paris"
  }.freeze

  def self.required?
    Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
  end

  def self.load
    missing = VARIABLES.values.select { |variable| ENV[variable].blank? }
    raise "Missing #{missing.join(', ')}: production refuses to boot without the legal notice's contact and host" if required? && missing.any?

    VARIABLES.to_h { |key, variable| [ key, ENV[variable].presence || DEVELOPMENT_VALUES[key] ] }
  end
end

Rails.application.config.x.legal = ActiveSupport::OrderedOptions.new.update(LegalSettings.load)
