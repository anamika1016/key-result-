class UserDetail < ApplicationRecord
  belongs_to :department
  belongs_to :activity
  belongs_to :employee_detail, optional: true  # optional if it can be nil

end
