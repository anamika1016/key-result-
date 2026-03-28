require "test_helper"

class UserTrainingProgressesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get user_training_progresses_index_url
    assert_response :success
  end

  test "should get show" do
    get user_training_progresses_show_url
    assert_response :success
  end

  test "should get create" do
    get user_training_progresses_create_url
    assert_response :success
  end

  test "should get update" do
    get user_training_progresses_update_url
    assert_response :success
  end
end
