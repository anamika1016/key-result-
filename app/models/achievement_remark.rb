class AchievementRemark < ApplicationRecord
  belongs_to :activity, optional: true
end
