class EmployeeDetail < ApplicationRecord
  validates :name, presence: true
  validates :employee_id, :employee_name, :employee_email, presence: true
  has_many :user_details, dependent: :destroy
 after_initialize :set_default_status, if: :new_record?

  def name
    employee_name
  end
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id
      employee_id
      employee_name
      employee_email
      employee_code
      l1_code
      l1_employer_name
      l2_code
      l2_employer_name
      post
      department
      created_at
      updated_at
    ]
  end


  enum :status, {
    pending: "pending",
    approved: "approved",
    rejected: "returned",
    l2_approved: "l2_approved",
    l2_returned: "l2_returned"

  }

  # ✅ Allow only safe associations (empty if none)
  def self.ransackable_associations(auth_object = nil)
    []
  end

  def set_default_status
   self.status ||= "pending"
  end
end
