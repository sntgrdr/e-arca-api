class ProvisionDefaultUserResourcesJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(user_id)
    user = User.find(user_id)

    return if Client.exists?(user_id: user.id, final_client: true)

    Iva.find_or_create_by!(user: user, percentage: 21) do |i|
      i.name = "IVA 21%"
    end

    Client.create!(
      active:          true,
      client_group_id: nil,
      iva_id:          nil,
      legal_name:      "Consumidor Final",
      legal_number:    "0",
      name:            "Consumidor Final",
      final_client:    true,
      tax_condition:   :final_client,
      user_id:         user.id,
      dni:             nil
    )
  end
end
