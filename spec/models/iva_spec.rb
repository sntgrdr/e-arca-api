require 'rails_helper'

RSpec.describe Iva, type: :model do
  it { should belong_to(:user) }
end
