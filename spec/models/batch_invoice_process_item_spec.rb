require 'rails_helper'

RSpec.describe BatchInvoiceProcessItem, type: :model do
  it 'is valid with a batch_invoice_process, item, and position' do
    bip  = create(:batch_invoice_process)
    item = create(:item, user: bip.user, iva: create(:iva, user: bip.user))
    record = described_class.new(batch_invoice_process: bip, item: item, position: 0)
    expect(record).to be_valid
  end

  it 'enforces uniqueness of item per batch' do
    bip  = create(:batch_invoice_process)
    item = create(:item, user: bip.user, iva: create(:iva, user: bip.user))
    described_class.create!(batch_invoice_process: bip, item: item, position: 0)
    dup = described_class.new(batch_invoice_process: bip, item: item, position: 1)
    expect(dup).not_to be_valid
  end
end
