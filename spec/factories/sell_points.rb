FactoryBot.define do
  factory :sell_point do
    association :user
    sequence(:number) { |n| n.to_s }
    name { 'Punto de Venta' }
  end
end
