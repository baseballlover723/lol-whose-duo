module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :id

    def connect
    end

    protected
    # def find_verified_user
    #   if current_user = User.find_by(id: cookies.signed[:user_id])
    #     current_user
    #   else
    #     reject_unauthorized_connection
    #   end
    # end
  end
end