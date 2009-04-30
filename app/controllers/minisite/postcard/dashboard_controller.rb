require 'uuid'

class Minisite::Postcard::DashboardController < ApplicationController
  before_filter :login_required, :except => :index
  
  def index
    @board = PublicBoard.find_by_slug("postcard").board
    @topics = @board.topics.find(:all, :order => "sticky desc, last_replied_at desc", :limit => 10)
    
    postcard = StuffType.find_by_slug("postcard")
    @school_bucks = postcard.bucks.find :all, :include => [:school] 
  end
  
  def password
    if params[:password].blank?
      set_message_and_redirect_to_index "请输入贺卡上的爱心密码, 点击验证按钮"
    else
      @stuff = Stuff.find_by_code(params[:password])
      if @stuff.nil?
        # 密码不正确，没找到对应的stuff
        set_message_and_redirect_to_index "您输入的密码不正确，请检查一下重新输入"
      else
        # 密码正确，找到stuff，进一步判断stuff是否已配对
        if @stuff.matched?
          # 已成功配对
          set_message_and_redirect_to_index "您这张贺卡已经选过学校"
        else
          # 尚未配对
          postcard = StuffType.find_by_slug("postcard")
          @bucks = postcard.bucks.find :all, :include => [:school], :conditions => ["matched_count < quantity"] 
          render :action => "school_list"
        end
      end
    end
  end
  
  def give
    @stuff = Stuff.find_by_code(params[:token])
    set_message_and_redirect_to_index("密码错误，请重新输入") if @stuff.blank?
    
    if @stuff.matched?
      flash[:notice] = "这张贺卡已经选过学校"
      
    else
      @buck = StuffBuck.find(params[:id])
      @stuff.user = current_user
      @stuff.school = @buck.school
      @stuff.matched_at = Time.now
      Stuff.transaction do 
        @stuff.save!
        @buck.update_attributes!(:matched_count => Stuff.count(:all, :conditions => ["school_id=?", @stuff.school]))
      end
      flash[:notice] = "密码配对完成，您捐给#{@stuff.school.title}一本书。"
      
    end
    redirect_to minisite_postcard_index_url
  end
  
  
  private
  def set_message_and_redirect_to_index(msg = "")
    flash[:postcard_notice] = msg
    redirect_to minisite_postcard_index_url
  end
  
  
=begin  
  def code_test
    1000.times do
      logger.info UUID.create_random.to_s.gsub("-", "").unpack('axaxaxaxaxaxaxax').join('')
    end
    render :action => "index"
  end
=end  
end