class Invoice < ApplicationRecord
  include Discard::Model

  belongs_to :user
  belongs_to :client
  belongs_to :sell_point

  has_many :lines, as: :lineable, dependent: :destroy
  accepts_nested_attributes_for :lines, allow_destroy: true

  enum :afip_status, {
    draft: "draft",
    submitting: "submitting",
    authorized: "authorized",
    rejected: "rejected"
  }

  scope :kept, -> { undiscarded }

  validates :number, :date, presence: true
  validates :number, uniqueness: { scope: [ :user_id, :type, :sell_point_id ], allow_nil: true }
  validates :number, numericality: { greater_than: 0 }
  validates :afip_status, presence: true

  def self.current_number(user_id, sell_point_id, invoice_type)
    (where(user_id: user_id, sell_point_id: sell_point_id, invoice_type: invoice_type)
      .maximum(Arel.sql("CAST(number AS INTEGER)")).to_i + 1).to_s
  end

  def self.all_my_invoices(user_id)
    kept.where(user_id: user_id)
  end

  def submittable?
    draft? || rejected?
  end

  def afip_authorized?
    cae.present?
  end
end
