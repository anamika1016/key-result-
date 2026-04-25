class Question < ApplicationRecord
  belongs_to :quiz

  validates :question, presence: true
  validates :correct_answer, presence: true
end
