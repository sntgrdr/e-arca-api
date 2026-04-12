require 'rails_helper'

RSpec.describe BatchInvoiceProcess, type: :model do
  it { should belong_to(:user) }
  it { should belong_to(:item).optional }
  it { should belong_to(:sell_point) }
  it { should belong_to(:client_group).optional }
  it { should have_many(:client_invoices) }
  it { should validate_presence_of(:date) }
  it { should validate_presence_of(:period) }
  it { should validate_presence_of(:status) }
end
