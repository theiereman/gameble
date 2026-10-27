module LegalHelper
  def legal_contact
    mail_to(Rails.configuration.x.legal.contact_email, class: "legal__link")
  end
end
