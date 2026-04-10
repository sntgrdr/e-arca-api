require 'rails_helper'

RSpec.describe ItemGroup, type: :model do
  it { should belong_to(:user) }
  it { should have_many(:items).dependent(:nullify) }

  it { should validate_presence_of(:name) }

  describe 'name uniqueness' do
    subject { build(:item_group) }

    it { should validate_uniqueness_of(:name).scoped_to(:user_id).case_insensitive }
  end

  describe '.all_my_item_groups scope' do
    it 'returns only groups belonging to the given user' do
      user_a = create(:user)
      user_b = create(:user)
      group_a = create(:item_group, user: user_a)
      create(:item_group, user: user_b)

      expect(ItemGroup.all_my_item_groups(user_a.id)).to contain_exactly(group_a)
    end
  end

  describe '.active scope' do
    it 'returns only active groups' do
      user = create(:user)
      active_group   = create(:item_group, user: user, active: true)
      inactive_group = create(:item_group, user: user, active: false)

      expect(ItemGroup.active).to include(active_group)
      expect(ItemGroup.active).not_to include(inactive_group)
    end
  end
end
