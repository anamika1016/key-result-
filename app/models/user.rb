# app/models/user.rb

class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  ROLES = %w[employee admin hod l1_employer l2_employer]
  # enum :role, { super_admin: 0, admin: 1, user: 2 }
validates :role, presence: true, on: :create
  

  def employee?
    role == 'employee'
  end

  def admin?
    role == 'admin'
  end
  def hod?
    role == 'hod'
  end

  def l1_employer?
    role == 'l1_employer'
  end

  def l2_employer?
    role == 'l2_employer'
  end
end
