class Client < ApplicationRecord
  has_paper_trail

  belongs_to :user
  belongs_to :iva, optional: true
  belongs_to :client_group, optional: true

  before_validation :sanitize_legal_number

  validates :legal_name, :legal_number, :tax_condition, presence: true
  validates :legal_name, :legal_number, uniqueness: { scope: :user_id, allow_nil: true }

  enum :tax_condition, ::Constants::Arca::TAX_CONDITIONS

  scope :all_my_clients, ->(user_id) { where(user_id: user_id) }

  private

  def sanitize_legal_number
    self.legal_number = legal_number.gsub(/\D/, '') if legal_number.present?
  end
  scope :active, -> { where(active: true) }
end
