class Activity < ApplicationRecord
  belongs_to :department, counter_cache: true

  has_many :user_details

  before_validation :set_default_year

  validates :year, presence: true

  private

  def set_default_year
    start_year = Date.current.month >= 4 ? Date.current.year : Date.current.year - 1
    self.year ||= if self.class.columns_hash["year"]&.type == :integer
      start_year
    else
      end_year = start_year + 1
      "#{start_year.to_s[-2, 2]}-#{end_year.to_s[-2, 2]}"
    end
  end
end
