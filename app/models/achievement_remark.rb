class AchievementRemark < ApplicationRecord
  belongs_to :achievement, optional: true
  belongs_to :activity, optional: true

  # Ensure percentage values are always numeric
  before_save :normalize_percentages

  private

  def normalize_percentages
    # Safely convert percentage values to float, defaulting to 0.0 for nil/invalid values
    self.l1_percentage = safe_percentage_conversion(l1_percentage) if l1_percentage_changed?
    self.l2_percentage = safe_percentage_conversion(l2_percentage) if l2_percentage_changed?
    self.l3_percentage = safe_percentage_conversion(l3_percentage) if l3_percentage_changed?
  end

  def safe_percentage_conversion(value)
    return 0.0 if value.nil? || value == ""
    begin
      Float(value)
    rescue ArgumentError, TypeError
      0.0
    end
  end
end
