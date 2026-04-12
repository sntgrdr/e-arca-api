require 'rails_helper'

RSpec.describe BatchInvoiceProcessClient, type: :model do
  it 'is valid with a batch_invoice_process and client' do
    bip    = create(:batch_invoice_process)
    iva    = create(:iva, user: bip.user)
    client = create(:client, user: bip.user, iva: iva)
    record = described_class.new(batch_invoice_process: bip, client: client)
    expect(record).to be_valid
  end

  it 'enforces uniqueness of client per batch' do
    bip    = create(:batch_invoice_process)
    iva    = create(:iva, user: bip.user)
    client = create(:client, user: bip.user, iva: iva)
    described_class.create!(batch_invoice_process: bip, client: client)
    dup = described_class.new(batch_invoice_process: bip, client: client)
    expect(dup).not_to be_valid
  end
end
