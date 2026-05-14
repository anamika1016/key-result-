require "test_helper"

class QuizTest < ActiveSupport::TestCase
  test "plain duration numbers are treated as minutes" do
    quiz = Quiz.new(duration: "30")

    assert_equal 30.minutes.to_i, quiz.duration
  end

  test "duration supports seconds minutes hours and clock format" do
    assert_equal 45, Quiz.new(duration: "45s").duration
    assert_equal 5.minutes.to_i, Quiz.new(duration: "5m").duration
    assert_equal 5.minutes.to_i, Quiz.new(duration: "5.0").duration
    assert_equal 90.minutes.to_i, Quiz.new(duration: "1.5h").duration
    assert_equal 90.minutes.to_i + 15, Quiz.new(duration: "1h 30m 15s").duration
    assert_equal 1.hour.to_i + 2.minutes.to_i + 3, Quiz.new(duration: "01:02:03").duration
  end

  test "duration label displays saved seconds nicely" do
    quiz = Quiz.new(duration: 3_723)

    assert_equal "1h 2m 3s", quiz.duration_label
  end

  test "duration value and unit split for form" do
    quiz = Quiz.new(duration: 45)
    assert_equal 45, quiz.duration_value_for_form
    assert_equal "seconds", quiz.duration_unit_for_form

    quiz.duration = 30.minutes
    assert_equal 30, quiz.duration_value_for_form
    assert_equal "minutes", quiz.duration_unit_for_form

    quiz.duration = 2.hours
    assert_equal 2, quiz.duration_value_for_form
    assert_equal "hours", quiz.duration_unit_for_form
  end
end
