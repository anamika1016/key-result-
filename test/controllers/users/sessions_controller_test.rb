require "test_helper"
require "openssl"

class Users::SessionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "signs in with employee code and password without email" do
    user = User.create!(
      email: "session.employee@example.com",
      employee_code: "EMPLOGIN",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    post user_session_path, params: {
      user: {
        employee_code: user.employee_code,
        password: "password123"
      }
    }

    assert_redirected_to settings_path
  end

  test "rejects unknown employee code" do
    post user_session_path, params: {
      user: {
        employee_code: "UNKNOWN",
        password: "password123"
      }
    }

    assert_redirected_to new_user_session_path
    assert_equal "No account found with that employee code. Please check your employee code and try again.", flash[:alert]
  end

  test "employee code sign in link redirects when current user matches requested code" do
    user = User.create!(
      email: "session.link.match@example.com",
      employee_code: "EMPLINK",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )
    sign_in user, scope: :user

    get employee_code_user_session_path(employee_code: " emplink ")

    assert_redirected_to settings_path
  end

  test "sign in page signs in directly when employee code exists in employee list" do
    user = User.create!(
      email: "session.query.employee@example.com",
      employee_code: "1025",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )
    EmployeeDetail.create!(
      employee_name: "Query Employee",
      employee_email: user.email,
      employee_code: user.employee_code
    )

    get new_user_session_path, params: { employee_code: "1025" }

    assert_redirected_to settings_path
  end

  test "employee code sign in link signs in directly when employee code exists in employee list" do
    user = User.create!(
      email: "session.link.employee.list@example.com",
      employee_code: "EMPLINK",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )
    EmployeeDetail.create!(
      employee_name: "Link Employee",
      employee_email: user.email,
      employee_code: user.employee_code
    )

    get employee_code_user_session_path(employee_code: " emplink ")

    assert_redirected_to settings_path
  end

  test "employee code sign in link signs in requested employee when current user does not match requested code" do
    user = User.create!(
      email: "session.link.mismatch@example.com",
      employee_code: "EMPOTHER",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )
    requested_user = User.create!(
      email: "session.link.requested@example.com",
      employee_code: "EMPLINK",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )
    EmployeeDetail.create!(
      employee_name: "Requested Employee",
      employee_email: requested_user.email,
      employee_code: requested_user.employee_code
    )
    sign_in user, scope: :user

    get employee_code_user_session_path(employee_code: "EMPLINK")

    assert_redirected_to settings_path
  end

  test "employee code sign in link opens login page when code is not in employee list" do
    get employee_code_user_session_path(employee_code: "EMPLINK")

    assert_redirected_to new_user_session_path(employee_code: "EMPLINK", auto_sign_in: "0")
    assert_equal "No account found with that employee code. Please check your employee code and try again.", flash[:alert]
  end

  test "employee code sign in link signs in requested user with valid external signature" do
    with_sso_secret do |secret|
      user = User.create!(
        email: "session.link.sso@example.com",
        employee_code: "109",
        password: "password123",
        password_confirmation: "password123",
        role: "employee"
      )
      year = "25-26"
      expires_at = 10.minutes.from_now.to_i.to_s
      signature = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{user.employee_code}:#{year}:#{expires_at}")

      get employee_code_user_session_path(employee_code: user.employee_code), params: {
        year: year,
        expires_at: expires_at,
        signature: signature
      }

      assert_redirected_to dashboard_path(year: year)
    end
  end

  test "employee code sign in link signs in requested user with valid external signature and no year" do
    with_sso_secret do |secret|
      user = User.create!(
        email: "session.link.sso.no.year@example.com",
        employee_code: "109",
        password: "password123",
        password_confirmation: "password123",
        role: "employee"
      )
      expires_at = 10.minutes.from_now.to_i.to_s
      signature = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{user.employee_code}:#{expires_at}")

      post employee_code_user_session_path(employee_code: user.employee_code), params: {
        expires_at: expires_at,
        signature: signature
      }

      assert_redirected_to settings_path
    end
  end

  test "employee code sign in link opens login page with invalid external signature" do
    with_sso_secret do
      get employee_code_user_session_path(employee_code: "109"), params: {
        expires_at: 10.minutes.from_now.to_i,
        signature: "wrong"
      }

      assert_redirected_to new_user_session_path(employee_code: "109", auto_sign_in: "0")
      assert_equal "Invalid or expired sign in link. Please sign in again.", flash[:alert]
    end
  end

  private

  def with_sso_secret
    old_secret = ENV["ESS_SSO_SECRET"]
    secret = "test-sso-secret"
    ENV["ESS_SSO_SECRET"] = secret
    yield secret
  ensure
    ENV["ESS_SSO_SECRET"] = old_secret
  end
end
