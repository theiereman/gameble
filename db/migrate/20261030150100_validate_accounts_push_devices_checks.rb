class ValidateAccountsPushDevicesChecks < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :accounts_push_devices, name: "accounts_push_devices_platform_check"
    validate_check_constraint :accounts_push_devices, name: "accounts_push_devices_token_length_check"
  end
end
