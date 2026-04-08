require 'rails_helper'

RSpec.describe ClientGroup, type: :model do
  it { should belong_to(:user) }
  it { should have_many(:clients) }
  it { should validate_presence_of(:name) }

  describe 'uniqueness' do
    subject { build(:client_group) }
    it { should validate_uniqueness_of(:name).scoped_to(:user_id) }
  end
end
