class GamesController < ApplicationController
  before_filter :login_required, :only => [:new, :create, :edit, :update]
  before_filter :check_category, :only => [:category, :new]
  
  uses_tiny_mce :options => { :theme => 'advanced',
  :browsers => %w{msie gecko safari},   
  :theme_advanced_layout_manager => "SimpleLayout",
  :theme_advanced_statusbar_location => "bottom",
  :theme_advanced_toolbar_location => "top",
  :theme_advanced_toolbar_align => "left",
  :theme_advanced_resizing => true,
  :relative_urls => false,
  :convert_urls => false,
  :cleanup => true,
  :cleanup_on_startup => true,  
  :convert_fonts_to_spans => true,
  :theme_advanced_resize_horizontal => false,
  :theme_advanced_buttons1 => ["undo,redo,|,cut,copy,paste,|,bold,italic,underline,strikethrough,|,justifyleft,justifycenter,justifyright,justifyfull,|,bullist,numlist,|,link,unlink,|,image,emotions"],
  :theme_advanced_buttons2 => [],
  :language => :en,
  :plugins => %w{contextmenu advimage paste fullscreen} }, :only => [:new, :create, :edit, :update]
  
  def index
    @games = {}
    Game::CATEGORIES.each do |category|
      @games[category] = Game.category(category).limit(5)
    end
  end
  
  def category
    @category = params[:category]
    @games = Game.category(@category).paginate(:page => params[:page], :per_page => 20)
  end
  
  def show
    @game = Game.find(params[:id])
    @game.revert_to(params[:version]) if params[:version]
  end
  
  def new
    @game = Game.new(:category => @category)
  end
  
  def create
    @game = Game.new(params[:game])
    @game.user_id = current_user.id

    respond_to do |want|
      if @game.save
        want.html { redirect_to  @game }
      else
        want.html { render 'new' }
      end
    end
  end
  
  def edit
    @game = Game.find(params[:id])
  end
  
  def update
    @game = Game.find(params[:id])
    @game.user_id = current_user.id
    
    respond_to do |want|
      if @game.update_attributes(params[:game])
        want.html {redirect_to @game}
      else
        want.html {render 'edit'}
      end
    end
  end
end