class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  enum :tax_condition, ::Constants::Arca::TAX_CONDITIONS.symbolize_keys

  validates :legal_name, uniqueness: { case_sensitive: false }
  validates :legal_number,
            uniqueness: true,
            unless: -> { legal_number == '11-11111111-1' }
end
