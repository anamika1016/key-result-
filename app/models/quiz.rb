class Quiz < ApplicationRecord
  QUESTION_MEDIA_FILES = %w[
    istockphoto-1866678152-640_adpp_is.mp4
    istockphoto-2086014968-640_adpp_is.mp4
    istockphoto-2152144925-640_adpp_is.mp4
    istockphoto-2152318415-640_adpp_is.mp4
    istockphoto-2222880045-640_adpp_is.mp4
    istockphoto-2229047105-640_adpp_is.mp4
  ].freeze

  has_many :questions, dependent: :destroy
  has_many :quiz_submissions, dependent: :destroy

  accepts_nested_attributes_for :questions, allow_destroy: true, reject_if: :all_blank

  before_validation :ensure_qr_token

  validates :title, presence: true
  validates :qr_token, presence: true, uniqueness: true

  def public_quiz_path
    "/quiz_access/#{qr_token}"
  end

  def duration_in_seconds
    return 0 unless duration.to_i.positive?

    duration.to_i.minutes
  end

  def question_media_files
    QUESTION_MEDIA_FILES
  end

  private

  def ensure_qr_token
    self.qr_token ||= SecureRandom.urlsafe_base64(10)
  end
end
