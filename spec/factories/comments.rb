FactoryBot.define do
  factory :comment do
    association :user
    body { "Test comment" }
    commentable { nil }
  end
end
