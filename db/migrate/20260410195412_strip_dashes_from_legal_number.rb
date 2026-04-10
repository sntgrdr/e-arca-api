class StripDashesFromLegalNumber < ActiveRecord::Migration[8.1]
  def up
    User.find_each do |user|
      next if user.legal_number.blank? || !user.legal_number.include?("-")

      user.update_column(:legal_number, user.legal_number.gsub("-", ""))
    end
  end

  def down
    User.find_each do |user|
      next if user.legal_number.blank? || user.legal_number.length != 11

      digits = user.legal_number
      user.update_column(:legal_number, "#{digits[0..1]}-#{digits[2..9]}-#{digits[10]}")
    end
  end
end
