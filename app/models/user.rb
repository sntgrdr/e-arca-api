class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :validatable, :lockable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  enum :tax_condition, ::Constants::Arca::TAX_CONDITIONS.symbolize_keys

  validate :password_complexity, if: -> { password.present? }
  validate :dni_matches_legal_number, if: -> { dni.present? && legal_number.present? }

  validates :legal_name, uniqueness: { case_sensitive: false }
  validates :legal_number,
            uniqueness: true,
            unless: -> { legal_number == "11-11111111-1" }
  validates :dni, uniqueness: true, allow_nil: true

  private

  def dni_matches_legal_number
    return if legal_number.gsub("-", "").include?(dni)

    errors.add(:dni, :mismatch, message: I18n.t("errors.messages.dni_mismatch"))
  end

  def password_complexity
    return if password.match?(/[A-Z]/) && password.match?(/[\-._]/)

    errors.add(:password, :complexity,
               message: I18n.t("errors.messages.password_complexity"))
  end
end
