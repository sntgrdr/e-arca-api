require 'rails_helper'

RSpec.describe Line, type: :model do
  it { should belong_to(:lineable) }
  it { should belong_to(:item) }
  it { should belong_to(:user) }
  it { should belong_to(:iva).optional }
  it { should validate_presence_of(:description) }
  it { should validate_presence_of(:quantity) }
  it { should validate_presence_of(:unit_price) }
  it { should validate_presence_of(:final_price) }
end
