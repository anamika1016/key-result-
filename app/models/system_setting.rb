class SystemSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.dashboard_active?
    setting = find_by(key: "dashboard_active")
    setting.nil? ? true : setting.value == "true"
  end

  def self.set_dashboard_active(status)
    setting = find_or_initialize_by(key: "dashboard_active")
    setting.value = status.to_s
    setting.save
  end
end
