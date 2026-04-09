class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :validatable, :lockable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  enum :tax_condition, ::Constants::Arca::TAX_CONDITIONS.symbolize_keys

  validate :password_complexity, if: -> { password.present? }

  validates :legal_name, uniqueness: { case_sensitive: false }
  validates :legal_number,
            uniqueness: true,
            unless: -> { legal_number == "11-11111111-1" }

  private

  def password_complexity
    return if password.match?(/[A-Z]/) && password.match?(/[\-._]/)

    errors.add(:password, :complexity,
               message: I18n.t("errors.messages.password_complexity"))
  end
end
