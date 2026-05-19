class Quiz < ApplicationRecord
  has_many :questions, dependent: :destroy
  has_many :quiz_submissions, dependent: :destroy
  has_many :user_quizzes, dependent: :nullify

  accepts_nested_attributes_for :questions, allow_destroy: true, reject_if: :all_blank

  before_validation :ensure_qr_token

  validates :title, presence: true
  validates :qr_token, presence: true, uniqueness: true
  validates :duration, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  def duration=(value)
    super(self.class.parse_duration_to_seconds(value))
  end

  def public_quiz_path
    "/quiz_access/#{qr_token}"
  end

  def active_for_access?
    status.to_s.strip.casecmp("active").zero?
  end

  def duration_in_seconds
    duration.to_i
  end

  def duration_for_form
    self.class.format_duration(duration)
  end

  def duration_value_for_form
    total_seconds = duration.to_i
    return nil unless total_seconds.positive?

    case duration_unit_for_form
    when "hours"
      total_seconds / 3600
    when "minutes"
      total_seconds / 60
    else
      total_seconds
    end
  end

  def duration_unit_for_form
    total_seconds = duration.to_i
    return "minutes" unless total_seconds.positive?

    if (total_seconds % 3600).zero?
      "hours"
    elsif (total_seconds % 60).zero?
      "minutes"
    else
      "seconds"
    end
  end

  def duration_label
    self.class.format_duration(duration).presence || "0s"
  end

  def self.parse_duration_to_seconds(value)
    return value.to_i if defined?(ActiveSupport::Duration) && value.is_a?(ActiveSupport::Duration)
    return value if value.is_a?(Numeric)

    text = value.to_s.strip.downcase
    return nil if text.blank?

    if text.match?(/\A\d+(\.\d+)?\z/)
      return text.to_f.minutes.to_i
    end

    if text.match?(/\A\d{1,2}:\d{1,2}(:\d{1,2})?\z/)
      parts = text.split(":").map(&:to_i)
      parts.length == 3 ? parts[0].hours.to_i + parts[1].minutes.to_i + parts[2] : parts[0].minutes.to_i + parts[1]
    else
      seconds = 0
      text.scan(/(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)/) do |amount, unit|
        amount = amount.to_f
        seconds += if unit.start_with?("h")
          amount.hours.to_i
        elsif unit.start_with?("m")
          amount.minutes.to_i
        else
          amount.to_i
        end
      end

      seconds.positive? ? seconds : nil
    end
  end

  def self.format_duration(total_seconds)
    total_seconds = total_seconds.to_i
    return "" unless total_seconds.positive?

    hours = total_seconds / 3600
    minutes = (total_seconds % 3600) / 60
    seconds = total_seconds % 60

    [
      ("#{hours}h" if hours.positive?),
      ("#{minutes}m" if minutes.positive?),
      ("#{seconds}s" if seconds.positive?)
    ].compact.join(" ")
  end

  private

  def ensure_qr_token
    self.qr_token ||= SecureRandom.urlsafe_base64(10)
  end
end
