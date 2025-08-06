  class Department < ApplicationRecord
    has_many :activities, dependent: :destroy
    has_many :user_details
    
    accepts_nested_attributes_for :activities, allow_destroy: true, reject_if: :all_blank
  end