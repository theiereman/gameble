module Accounts
  ClerkUser = Data.define(:id, :external_accounts, :primary_verified_email)
  ClerkUser::ExternalAccount = Data.define(:provider, :uid, :email, :verified)
end
