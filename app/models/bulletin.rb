class Bulletin < ActiveRecord::Base
  acts_as_taggable
  
  belongs_to :user
  
  validates_presence_of :title, :message => "不能为空"
  
  attr_accessible :title, :body, :tag_list, :user_id
  
  named_scope :recent, :limit => 5, :order => 'id DESC'
end