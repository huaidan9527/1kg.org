class GeosController < ApplicationController
  def index
    @province = params[:province]? Geo.find( params[:province]) : nil
    @cities  = Geo.roots
    @map_center = @province ? [@province.latitude,@province.longitude,7] : Geo::DEFAULT_CENTER
    @schools = School.validated.paginate(:page => params[:page], :per_page => 10)
    
    respond_to do |format|
      if !params[:page].blank?
        format.html {render :action => 'schools', :layout => false}
      else
        format.html
      end
    end
  end
  
  def all
    redirect_to geos_path
  end
  
  def show
    @city = @province = params[:id] ? Geo.find( params[:id]) : nil
    @cities  = Geo.roots
    @map_center = @province ? [@province.latitude,@province.longitude,7] : Geo::DEFAULT_CENTER
    @schools = School.validated.paginate(:page => params[:page], :per_page => 10)
    
    @schools = School.near_to(@city).paginate(:page => params[:page] || 1, :per_page => 10)
    @activities = Activity.ongoing.for_the_city(@city).find :all, :order => "created_at desc", :limit => 10
    
    respond_to do |format|
      if !params[:page].blank?
        format.html {render :action => 'schools', :layout => false}
      else
        format.html
      end
    end
  end
  
  def box
    @city = Geo.find(params[:id])
    
    respond_to do |format|
      if !@city.children.blank?
        @cities = @city.children
        format.html {render :partial => 'geo_box', :locals => {:geos => @cities}, :layout => false}
      else
        setup_destination_stuff(@city)
        format.html {render :partial => 'city_box', :locals => {:city => @city}, :layout => false}
      end
    end
  end
  
  def shares
    @city = Geo.find(params[:id])
    @all_citizens = @city.users.find(:all, :order => "created_at desc", :select => "users.id")
    @shares = Share.paginate(:page => params[:page], :per_page => 20,
                               :conditions => ["user_id in (?)", @all_citizens.flatten],
                               :order => "last_replied_at desc")
  end
  
  def search
    @query = params[:city]
    if !@query.to_s.strip.empty?
      tokens = @query.split.collect {|c| "%#{c.downcase}%"}
      @cities = Geo.find(:all, :conditions => [(["(LOWER(name) LIKE ?)"] * tokens.size).join(" AND "), * tokens])
      if @cities.size == 1
        redirect_to :action => "index", :province => @cities[0].id
      end
    else
      @cities = Geo.roots
    end
  end
  
  def schools
    @city = Geo.find(params[:id])
    @all_schools = School.near_to(@city)
    
    respond_to do |format|
      format.html do
        @schools = @all_schools.paginate(:page => params[:page] || 1,
                                      :per_page => 10)
        render :layout => false
      end
      
      format.json do
        schools_json = []
        @all_schools.each do |school|
          next if school.basic.blank?
          schools_json << {:i => school.id,
                           :t => school.icon_type,
                           :n => school.title,
                           :a => school.basic.latitude,
                           :o => school.basic.longitude
                          }
        end
        render :text => "var schools =#{schools_json.to_json}", :layout => false
      end
    end
  end
  
  # for multiple drop down select
  def geo_choice
    if !params[:root].blank?
      if params[:root].to_i == 0
        # 用户选了不限地域
        @geos = [{:name => "不限地域", :id => 0}]
      else
        @root = Geo.find(params[:root])
        if @root.children.size > 0
          @geos = @root.children.collect{|r| {:name => r.name, :id => r.id} }
        else
          @geos = [ {:name => @root.name, :id => @root.id} ]
        end
      end
    else
      @geos = Array.new
    end
    render :partial => "/geos/geo_selector", :locals => { :object => params[:object], :method => params[:method] }
  end
  
  def county_choice
    if !params[:geo].blank?
      @geo = Geo.find(params[:geo])
      if @geo.counties.size > 0
        @counties = @geo.counties
      else
        @counties = []
      end
      render :partial => "geo_selector", :locals => { :object => "school", :method => "county" }
    end
  end
  
  def users
    @city = Geo.find(params[:id])
    @users = @city.users
    render :action => "users"
  end
  
  private 
  def setup_destination_stuff(city)
    @schools = School.near_to(city).paginate(:page => params[:page] || 1,
                                                          :order => "updated_at desc",
                                                          :per_page => 10)
    @shares = city.shares.paginate(:page => params[:page] || 1, :order => "comments_count desc", :per_page => 10)
    @activities = Activity.available.ongoing.find(:all, :conditions => ["arrival_id=?", city.id],
                                                        :order => "start_at desc",
                                                        :select => "id, title, start_at")
  end
  
end