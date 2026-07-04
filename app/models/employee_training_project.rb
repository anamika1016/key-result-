class EmployeeTrainingProject < ApplicationRecord
  before_validation :normalize_name

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  def self.option_names
    active.ordered.pluck(:name)
  end

  private

  def normalize_name
    self.name = name.to_s.strip.presence
  end
end
