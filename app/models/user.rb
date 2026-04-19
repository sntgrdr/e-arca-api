# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  account_number         :string           default(""), not null
#  active                 :boolean          default(TRUE)
#  activity_start         :date
#  address                :string
#  alias_account          :string           default(""), not null
#  arca_sign              :text
#  arca_token             :text
#  arca_token_expires_at  :datetime
#  cai                    :string           default(""), not null
#  city                   :string
#  country                :string
#  dni                    :string
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  failed_attempts        :integer          default(0), not null
#  legal_name             :string           default(""), not null
#  legal_number           :string           default(""), not null
#  locked_at              :datetime
#  name                   :string           default(""), not null
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  state                  :string
#  tax_condition          :integer          default(NULL), not null
#  unlock_token           :string
#  zip_code               :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_dni                              (dni) UNIQUE
#  index_users_on_email                            (email) UNIQUE
#  index_users_on_legal_name                       (legal_name) UNIQUE
#  index_users_on_legal_number_unique_except_ones  (legal_number) UNIQUE WHERE ((legal_number)::text <> '11-11111111-1'::text)
#  index_users_on_reset_password_token             (reset_password_token) UNIQUE
#  index_users_on_unlock_token                     (unlock_token) UNIQUE
#
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :validatable, :lockable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  enum :tax_condition, ::Constants::Arca::TAX_CONDITIONS.symbolize_keys

  after_create_commit :provision_default_resources

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

  def provision_default_resources
    ProvisionDefaultUserResourcesJob.perform_later(id)
  end

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
