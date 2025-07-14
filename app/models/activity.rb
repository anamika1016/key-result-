class Activity < ApplicationRecord
  belongs_to :department
    
  has_many :user_details
  validates :activity_id, presence: true, uniqueness: { scope: :department_id }
  validates :activity_name, presence: true
  validates :unit, presence: true
  validates :weight, presence: true, numericality: { greater_than: 0 }
end