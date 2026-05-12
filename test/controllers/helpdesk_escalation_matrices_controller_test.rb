require "test_helper"

class HelpdeskEscalationMatricesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @hod_user = User.create!(
      email: "hod.helpdesk@example.com",
      employee_code: "HOD900",
      password: "password123",
      password_confirmation: "password123",
      role: "hod"
    )

    @department = Department.create!(
      department_type: "HR",
      theme_id: 22,
      theme_name: "People"
    )

    @l1_user = User.create!(
      email: "hr.l1@example.com",
      employee_code: "HR001",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    @l2_user = User.create!(
      email: "hr.l2@example.com",
      employee_code: "HR002",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    @l3_user = User.create!(
      email: "hr.l3@example.com",
      employee_code: "HR003",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    @l4_user = User.create!(
      email: "hr.l4@example.com",
      employee_code: "HR004",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )
  end

  test "should get index for hod" do
    sign_in @hod_user

    get helpdesk_escalation_matrices_url

    assert_response :success
    assert_select "h1", "Helpdesk Escalation Matrix"
  end

  test "should create escalation matrix with dynamic levels" do
    sign_in @hod_user

    assert_difference("HelpdeskEscalationMatrix.count", 1) do
      assert_difference("HelpdeskEscalationLevel.count", 4) do
        post helpdesk_escalation_matrices_url, params: {
          helpdesk_escalation_matrix: {
            department_id: @department.id,
            escalation_levels_attributes: escalation_levels_for(@l1_user, @l2_user, @l3_user, @l4_user)
          }
        }
      end
    end

    matrix = HelpdeskEscalationMatrix.order(:id).last

    assert_redirected_to helpdesk_escalation_matrices_url
    assert_equal [ 1, 2, 3, 4 ], matrix.ordered_levels.pluck(:position)
    assert_equal [ @l1_user.id, @l2_user.id, @l3_user.id, @l4_user.id ], matrix.ordered_levels.pluck(:user_id)
  end

  private

  def escalation_levels_for(*users)
    users.each_with_index.map do |user, index|
      {
        position: index + 1,
        user_id: user.id
      }
    end
  end
end
