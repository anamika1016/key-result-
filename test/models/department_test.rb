require "test_helper"

class DepartmentTest < ActiveSupport::TestCase
  test "selectable verticals come only from departments" do
    assigned_vertical = Department.create!(department_type: "LWRD_SELECTABLE")
    Department.create!(department_type: "HR_SELECTABLE")
    employee = EmployeeDetail.create!(
      employee_name: "Test Employee",
      employee_code: "EMP-SELECTABLE",
      department: "HR"
    )
    activity = Activity.create!(department: assigned_vertical, activity_name: "Selectable Test Activity")
    UserDetail.create!(department: assigned_vertical, activity: activity, employee_detail: employee)

    selectable_verticals = Department.selectable_verticals.map(&:department_type)

    assert_includes selectable_verticals, "LWRD_SELECTABLE"
    assert_not_includes selectable_verticals, "HR_SELECTABLE"
    assert_not_includes selectable_verticals, "HR"
  end
end
