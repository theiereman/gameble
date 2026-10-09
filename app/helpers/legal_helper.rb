module LegalHelper
  def legal_contact
    contact_email = Rails.configuration.x.legal.contact_email
    contact_email ? mail_to(contact_email, class: "legal__link") : t("pages.legal.contact_fallback")
  end
end
