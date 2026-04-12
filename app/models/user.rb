class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :validatable, :lockable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  enum :tax_condition, ::Constants::Arca::TAX_CONDITIONS.symbolize_keys

  before_validation :sanitize_legal_number

  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validate :password_complexity, if: -> { password.present? }

  validates :legal_name, uniqueness: { case_sensitive: false }
  validates :legal_number,
            uniqueness: { allow_nil: true },
            unless: -> { legal_number == "11111111111" }
  validates :dni, uniqueness: { allow_nil: true }
  validate :dni_matches_legal_number, if: -> { dni.present? && legal_number.present? }

  private

  def password_complexity
    return if password.match?(/[A-Z]/) && password.match?(/[\-._]/)

    errors.add(:password, :complexity,
               message: I18n.t("errors.messages.password_complexity"))
  end

  def sanitize_legal_number
    self.legal_number = legal_number.gsub(/\D/, "") if legal_number.present?
  end

  def dni_matches_legal_number
    unless legal_number[2, 8] == dni
      errors.add(:dni, I18n.t("errors.messages.dni_mismatch"))
    end
  end
end
