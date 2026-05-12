require "test_helper"

class HelpdeskEscalationMatrixTest < ActiveSupport::TestCase
  setup do
    @department = Department.create!(
      department_type: "IT",
      theme_id: 11,
      theme_name: "Support"
    )

    @l1_user = User.create!(
      email: "l1.helpdesk@example.com",
      employee_code: "L1001",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    @l2_user = User.create!(
      email: "l2.helpdesk@example.com",
      employee_code: "L2001",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    @l3_user = User.create!(
      email: "l3.helpdesk@example.com",
      employee_code: "L3001",
      password: "password123",
      password_confirmation: "password123",
      role: "hod"
    )

    @l4_user = User.create!(
      email: "l4.helpdesk@example.com",
      employee_code: "L4001",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )
  end

  test "requires unique department per matrix" do
    HelpdeskEscalationMatrix.create!(
      department: @department,
      escalation_levels_attributes: escalation_levels_for(@l1_user, @l2_user, @l3_user)
    )

    duplicate_matrix = HelpdeskEscalationMatrix.new(
      department: @department,
      escalation_levels_attributes: escalation_levels_for(@l1_user, @l2_user, @l3_user)
    )

    assert_not duplicate_matrix.valid?
    assert_includes duplicate_matrix.errors[:department_id], "has already been taken"
  end

  test "supports additional escalation levels beyond l3" do
    matrix = HelpdeskEscalationMatrix.create!(
      department: @department,
      escalation_levels_attributes: escalation_levels_for(@l1_user, @l2_user, @l3_user, @l4_user)
    )

    assert_equal [ 1, 2, 3, 4 ], matrix.ordered_levels.map(&:position)
    assert_equal [ @l1_user.id, @l2_user.id, @l3_user.id, @l4_user.id ], matrix.ordered_levels.map(&:user_id)
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
