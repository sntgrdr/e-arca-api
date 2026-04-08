class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :legal_name, :legal_number, :name,
             :address, :city, :state, :zip_code, :country,
             :tax_condition, :activity_start, :cai,
             :account_number, :alias_account, :active
end
