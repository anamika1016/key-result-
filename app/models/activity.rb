class Activity < ApplicationRecord
  belongs_to :department, counter_cache: true

  has_many :user_details
end
