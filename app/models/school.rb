class School < ActiveRecord::Base
  
  belongs_to :user
  belongs_to :geo
  belongs_to :county
  belongs_to :validator, :class_name => "User", :foreign_key => "validated_by_id"

  has_one    :basic,   :class_name => "SchoolBasic"
  has_one    :traffic, :class_name => "SchoolTraffic"   # Should be removed.
  has_one    :need,    :class_name => "SchoolNeed"
  has_one    :contact, :class_name => "SchoolContact"
  has_one    :local,   :class_name => "SchoolLocal"
  has_one    :finder,  :class_name => "SchoolFinder"
  belongs_to :main_photo, :class_name => 'Photo'
  has_many   :snapshots, :class_name => "SchoolSnapshot"
  
  accepts_nested_attributes_for :basic, :traffic, :need, :contact, :local, :finder, :main_photo

  
  acts_as_ownable
  acts_as_manageable
  
  has_many :topics, :as => 'boardable', :order => "sticky desc,id desc", :dependent => :destroy
  has_many :photos, :as => 'photoable', :order => "id desc", :dependent => :destroy
  has_many :activities, :order => "id desc"
  has_many :requirements, :order => "id desc", :dependent => :destroy
  has_many :executions, :order => "id desc", :dependent => :destroy
  has_many :donations, :dependent => :destroy
  has_many :visited, :dependent => :destroy
  has_many :visitors, :through => :visited, 
                      :source => :user, 
                      :conditions => "status = #{Visited.status('visited')}"
                      
  has_many :interestings, :through => :visited, 
                          :source => :user, 
                          :conditions => "status = #{Visited.status('interesting')}"

  has_many :wannas, :through => :visited, 
                          :source => :user, 
                          :conditions => "status = #{Visited.status('wanna')}"

  has_many :co_donations, :order => "id desc", :dependent => :destroy
  
  has_many :followings, :as => "followable"
  has_many :followers, :through => :followings

  delegate :address, :zipcode, :master, :telephone, :level_amount, :teacher_amount, :student_amount, :class_amount,:intro, :to => :basic

  
  named_scope :validated, :conditions => {:validated => true, :meta => false}, :order => "created_at desc"
  named_scope :not_validated, :conditions => {:validated => false, :meta => false}, :order => "created_at desc"  
  named_scope :at, lambda { |city|
    geo_id = ((city.class == Geo) ? city.id : city)
    {:conditions => ["(geo_id=?)", geo_id]}
  }
  
  named_scope :locate, lambda { |city_ids|
    {:conditions => ["geo_id in (?)", city_ids]}
  }
  named_scope :top10_popular, :order => 'last_month_karma DESC', :limit => 6
  named_scope :recent_upload, :order => "created_at desc", :limit => 6
  named_scope :include, lambda {|includes| {:include => includes}}
  
  @@city_neighbors = {
                        :beijing => {:id => 1, :neighbors => {:hebei => 3, :neimenggu => 27}},
                        :tianjin => {:id => 2, :neighbors => {:hebei => 3, :neimenggu => 27}},
                        :shanghai => {:id =>79, :neighbors => {:zhejiang => 94, :anhui => 106, :jiangxi => 134}},
                        :chongqing => {:id => 273, :neighbors => {:sichuan => 274}},
                        :hongkong => {:id => 391, :neighbors => {:guangdong => 216}},
                        :macao => {:id => 392, :neighbors => {:guangdong => 216, :fujian => 124}}
  }
  
  define_index do
    # fields
    indexes title
    indexes basic.address, :as => :address
    indexes geo.name, :as => :city
    indexes [need.book, need.stationary, need.sport, 
              need.cloth, need.accessory, need.medicine, need.course, 
              need.hardware, need.teacher, need.other], :as => :need
    indexes contact.name, :as => :contact
  end
  
  attr_accessor :city, :city_unit, :town, :town_unit, :village
  
  def validate
    self.errors.add(:intro, "学校简介超过了140字") if (intro && intro.mb_chars.size > 140)
  end
  
  def validate_on_create
    school = School.find_similiar_by_geo_id(self.title, self.geo_id)
    self.errors.add(:title, "我们发现#{self.geo.name}已经有了一所<a href='/schools/#{school.id}'>#{school.title}（点击访问）</a>，如果您确认这所学校和您要提交的学校不是同一所，请和我们的管理员联系。") if school
  end
  
  def before_create
    # 确保用户只提交了学校基本信息也不会出错
    self.traffic ||= SchoolTraffic.new
    self.need ||= SchoolNeed.new
    self.contact ||= SchoolContact.new
    self.finder ||= SchoolFinder.new
    self.local ||= SchoolLocal.new
  end
  
  def before_save
    # TODO: how to skip callbacks?
    if User.current_user
      self.last_modified_at = Time.now
      self.last_modified_by_id = User.current_user.id
    end
    
    # 将学校流行度存入数据库
    snapshot = self.snapshots.find_or_create_by_created_on(Date.today)
    snapshot.karma = karma
    snapshot.save
  end
  
  validates_presence_of :geo_id, :message => ""
  validates_presence_of :title, :message => ""
  validates_presence_of :user_id
  

  
  # 用于导入博客学校
  class << self
    def categories
      %w(小学 中学 四川灾区板房学校)
    end
  
    # ToDo: 需要和at以及locate scope合并
    def near_to(geo, limit = 0)
      params = {:order => "last_month_karma desc"}
      params[:limit] = limit unless limit.zero?
      
      if  geo.nil?
      elsif geo.leaf?
        params[:conditions] = ['geo_id = ?', geo.id]
      else
        ids =[geo.id]
        ids += geo.children.map(&:id)
        params[:conditions] = ['geo_id in (?)', ids]
      end
      
      self.validated.find(:all, params)
    end
    
    def count_of_near_to(geo)
      if geo.leaf?
        conditions = ['geo_id = ?', geo.id]
      else
        ids =[geo.id]
        ids += geo.children.map(&:id)
        conditions = ['geo_id in (?)', ids]
      end
      
      count(:conditions => conditions)
    end

    def find_similiar_by_geo_id(title, geo_id)
      self.find(:first, :conditions => ['geo_id = ? and title like ?', geo_id, "%#{title}%"]) rescue nil
    end
  end

  def hit!
    self.class.increment_counter :hits, id
  end

  def last_topic
    self.discussion.board.topics.find(:first, :order => "last_replied_at desc")
  end
    
  def deleted?
    deleted_at.blank? ? false : true
  end
  
  def validated_by(user)
    return has_moderator?(user) 
  end
  
  def visited?(user)
    return false unless user.class == User
    
    visited = Visited.find(:first, :conditions => ["user_id=? and school_id=?", user.id, self.id])
    if visited.nil?
      false
    elsif visited.status == Visited.status('visited')
      'visited'
    elsif visited.status == Visited.status('interesting')
      'interesting'
    elsif visited.status == Visited.status('wanna')
      'wanna'
    else
      raise "学校访问数据错误"
    end
  end
  
  # 0 => invalidated, 1 => valid, 2 => meta
  def icon_type
    meta ? 2 : (validated ? 1 : 0)
  end

  def self.archives(valid = true)
    date_func = "extract(year from created_at) as year,extract(month from created_at) as month"
    condition_time = valid ? "validated_at" : "created_at"
    counts = School.find_by_sql(["select count(*) as count, #{date_func} from schools where validated = ? and deleted_at is null and #{condition_time} < ? group by year,month order by year asc,month asc limit ? ", valid, Time.now,count.to_i])
    
    sum = 0
    result = counts.map do |entry|
      sum += entry.count.to_i
      {
        :name => entry.year + "年" + entry.month + "月",
        :month => entry.month.to_i,
        :year => entry.year.to_i,
        :delta => entry.count,
        :sum => sum
      }
    end
    return result.reverse
  end
  
  def name
    "学校: #{title}"
  end
  #include FusionChart
  # 绘制月活跃度变化图
  #def karma_chart
    #由于数据不足，先显示过去7天的活跃度变化
    #data = []
    #6.downto(0) do |i|
    #  day = Date.today - i.day
    #  snapshot = self.snapshots.find_by_created_on(day)
    #  karma = snapshot.nil? ? rand(10) : snapshot.karma
    #  data << [day.to_s, karma]
    #end
    
    #column_2d_chart("过去一周活跃度变化", data, '时间', 'Karma')
  #end
  
  def self.show_date(year, month, day, valid)
    if valid
      # 已验证学校，以验证时间为准
      self.find(:all, 
                          :order      => "schools.updated_at desc",
                          :conditions => ["validated_at LIKE ? and validated = ?", "#{year}-#{month}-#{day}%", true])
    else
      # 待验证学校，以提交时间为准
      self.find(:all,
                          :order => "schools.validated_at desc",
                          :conditions => ["created_at like ? and validated = ?", "#{year}-#{month}-#{day}%", false] )
    end
  end
  
end
