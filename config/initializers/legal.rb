Rails.application.config.x.legal = ActiveSupport::OrderedOptions.new.update(
  contact_email: ENV["LEGAL_CONTACT_EMAIL"].presence,
  host_name: ENV["LEGAL_HOST_NAME"].presence,
  host_address: ENV["LEGAL_HOST_ADDRESS"].presence
)
