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

  # Remove the presence validation since we're creating achievements without achievement values during approval
  # validates :achievement, presence: true
end