require 'rails_helper'

RSpec.describe SellPoint, type: :model do
  it { should belong_to(:user) }
  it { should have_many(:invoices) }

  describe '#only_one_default_per_user' do
    let(:user) { create(:user) }
    let!(:default_sp) { create(:sell_point, user: user, default: true) }

    it 'prevents two defaults for same user' do
      sp = build(:sell_point, user: user, default: true)
      expect(sp).not_to be_valid
    end
  end
end
