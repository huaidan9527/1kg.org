# == Schema Information
#
# Table name: neighborhoods
#
#  id          :integer(4)      not null, primary key
#  user_id     :integer(4)      not null
#  neighbor_id :integer(4)      not null
#  created_at  :datetime
#

class Neighborhood < ActiveRecord::Base
  belongs_to :user, :class_name => "User", :foreign_key => "user_id"
  belongs_to :neighbor, :class_name => "User", :foreign_key => "neighbor_id"
  
  after_create :send_message_notification
  after_create :create_following
  before_destroy :destroy_following
  
  private
  def send_message_notification
    title = "#{self.user.login}刚刚加你为好友了"
    content = "<p>你好，#{self.neighbor.login}：</p><br/>" + 
              "<p>#{self.user.login}刚刚加你为好友，去他/她的主页( http://www.1kg.org/users/#{self.user.id} )看看吧。</p>" +
              "<br/><p>-多背一公斤团队</p>"
    #Message.create_system_notification([self.neighbor_id], title, content)    
    msg = Message.new
    msg.author_id = 0
    msg.to = [self.neighbor_id]
    msg.subject = title
    msg.content = content
    msg.save!
  end
end
