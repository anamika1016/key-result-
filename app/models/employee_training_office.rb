class EmployeeTrainingOffice < ApplicationRecord
  before_validation :normalize_values

  validates :office_type, presence: true
  validate :office_or_fpo_present

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:office_type, :office_name, :fpo_name) }

  def self.option_groups
    active.ordered.each_with_object({}) do |row, grouped|
      office_type = row.office_type.to_s.strip
      next if office_type.blank?

      grouped[office_type] ||= { offices: [], fpos: [], fpos_by_office: {} }

      office_name = row.office_name.to_s.strip
      fpo_name = row.fpo_name.to_s.strip

      grouped[office_type][:offices] << office_name if office_name.present? && !grouped[office_type][:offices].include?(office_name)
      grouped[office_type][:fpos] << fpo_name if fpo_name.present? && !grouped[office_type][:fpos].include?(fpo_name)

      next if office_name.blank? || fpo_name.blank?

      grouped[office_type][:fpos_by_office][office_name] ||= []
      grouped[office_type][:fpos_by_office][office_name] << fpo_name unless grouped[office_type][:fpos_by_office][office_name].include?(fpo_name)
    end
  end

  private

  def normalize_values
    self.office_type = office_type.to_s.strip.presence
    self.office_name = office_name.to_s.strip.presence
    self.fpo_name = fpo_name.to_s.strip.presence
  end

  def office_or_fpo_present
    return if office_name.present? || fpo_name.present?

    errors.add(:base, "Office name or FPO name is required")
  end
end
