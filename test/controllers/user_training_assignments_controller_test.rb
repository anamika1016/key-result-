require "test_helper"

class UserTrainingAssignmentsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get user_training_assignments_index_url
    assert_response :success
  end

  test "should get show" do
    get user_training_assignments_show_url
    assert_response :success
  end

  test "should get create" do
    get user_training_assignments_create_url
    assert_response :success
  end

  test "should get destroy" do
    get user_training_assignments_destroy_url
    assert_response :success
  end
end
