module ApplicationHelper
    def current_user_detail
  current_user&.user_detail
end

end
