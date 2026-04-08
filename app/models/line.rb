class Line < ApplicationRecord
  belongs_to :lineable, polymorphic: true
  belongs_to :item
  belongs_to :user
  belongs_to :iva, optional: true

  validates :unit_price, :final_price, :quantity, :description, presence: true
  validates :unit_price, :final_price, :quantity, numericality: { greater_than: 0 }
end
