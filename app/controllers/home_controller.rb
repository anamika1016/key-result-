class HomeController < ApplicationController
   before_action :authenticate_user!

  def index
  end
  
  def dashboard
    case current_user.role
    when 'employee'
      redirect_to employee_details_path
    when 'hod'
      redirect_to new_user_detail_path
    when 'l1_employer'
      redirect_to l1_employee_details_path
    when 'l2_employer'
      redirect_to l2_employee_details_path
    else
      render plain: "No dashboard for this role"
    end
  end
end
