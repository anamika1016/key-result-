class HomeController < ApplicationController
   before_action :authenticate_user!

  def index
  end

  def dashboard
    if current_user.hod?
      redirect_to employee_details_path and return
    end

    if EmployeeDetail.exists?(l2_code: current_user.employee_code) || EmployeeDetail.exists?(l2_employer_name: current_user.email)
      redirect_to l2_employee_details_path and return
    end

    if EmployeeDetail.exists?(l1_code: current_user.employee_code)
      redirect_to l1_employee_details_path and return
    end

    if current_user.employee?
      redirect_to get_user_detail_user_details_path and return
    end

    # fallback if none of above
    render plain: "No dashboard or redirect for your role."
  end
end
