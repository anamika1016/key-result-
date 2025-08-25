class Achievement < ApplicationRecord
  belongs_to :user_detail
  has_one :achievement_remark, dependent: :destroy

  # validates :month, uniqueness: { scope: :user_detail_id }
  enum :status, {
      pending: "pending",
      l1_approved: "l1_approved",
      l1_returned: "l1_returned",
      l2_approved: "l2_approved",
      l2_returned: "l2_returned"
    }

  # FIXED: Ensure status is always set to pending by default
  before_validation :set_default_status, on: :create
  
  # FIXED: Validate that status is always present
  validates :status, presence: true

  # Remove the presence validation since we're creating achievements without achievement values during approval
  # validates :achievement, presence: true

  private

  def set_default_status
    self.status ||= 'pending'
  end
end