require "sinatra/base"
require "sinatra/reloader" if development?
require_relative "./config"
require "json"
require "sqlite3"
require "stripe"
require "bcrypt"

require_relative "./models/message"
require_relative "./models/order"
require_relative "./models/user"

class App < Sinatra::Base

  configure do #configure => körs när appen (sinatra) startas
    set :sessions, true #aktiverar sessions i sinatra så att data kan sparas i en cookie i webbläsaren så t.ex "session[:cart] = { "qty" => 2 }" => kunden behåller sin kundvagn när de byter sida
    #set :stripe_webhook_secret, ENV["STRIPE_WEBHOOK_SECRET"]
  end

 #Stripe.api_key = ENV.fetch['STRIPE_SECRET_KEY']

  configure :development do
   # register Sinatra::Reloader #så man slipper starta om servern varje gång smart.
  end

  def db
    return @db if @db
    @db = SQLite3::Database.new(DB_PATH)
    @db.results_as_hash = true
    @db
  end

  helpers do

    def money_kr(ore) #används i cart.erb, detta är den bästa lösningen jag kan komma på i stunden.
      kr = ore.to_i / 100.0
      format("%.0f kr", kr) #convertar tal till sträng utan decimaler, och lägg till suffix kr 
    end

    def cart
      session[:cart] ||= { "qty" => 0 }
    end

    def cart_qty
      cart["qty"].to_i
    end

    def logged_in?
      !!session[:user_id] #!! gör att det blir en boolean, om session[:user_id] har ett värde så blir det true annars false
    end

  end

  before do
    @logged_in = logged_in? #@logged_in är en instansvariabel som kan användas i alla views o den sätts till true eller false beroende på om användaren är inloggad eller inte
  end

  def protected!
    redirect "/login" unless logged_in? #om inte logged_in? så skickas användaren till login-sidan
  end

  get "/" do
    erb (:"/main/index")
  end

  post "/messages" do
    #name = params[:name].to_s.strip
    #email = params[:email].to_s.strip
    #subject = params[:subject].to_s.strip
    #message = params[:message].to_s.strip

    #db.execute(
      #"INSERT INTO messages (name, email, subject, message) VALUES (?, ?, ?, ?)",
      #[name, email, subject, message]
    #)
    Message.create(
    params[:name],
    params[:email],
    params[:subject],
    params[:message]
    )

    erb (:"/message/thanks")

  end

  post "/cart/add" do
    #session[:cart] ||= { "qty" => 0} # "||=" om det inte redan finns något värde här, sätt till detta ___.
    #session[:cart]["qty"] = session[:cart]["qty"].to_i + 1 
    cart["qty"] = cart_qty + 1
    redirect "/order/cart"
  end

  post "/cart/remove" do
    #session[:cart] ||= { "qty" => 0}
    #session[:cart]["qty"] = [session[:cart]["qty"].to_i - 1, 0].max #kan aldrig bli ett negativt värde därav , 0 och .max
    cart["qty"] = [cart_qty - 1, 0].max
    redirect "/order/cart"
  end

  get "/order/cart" do
    protected! #för att komma till kundvagnen måste man vara inloggad, annars skickas man till login-sidan
    #qty = session[:cart] ||= { "qty" => 0}
    #@qty = qty["qty"].to_i #@ = instansvariabel, @-variabler (instansvariabler) används när du vill skicka data till din erb-view, medan vanliga variabler utan @ bara behövs inne i routen
    @qty = cart_qty
    unit_price_ore = 44_900
    @subtotal_ore = @qty * unit_price_ore #subtotal = delsumma, fake
    erb (:"/order/cart")
  end

  post "/checkout" do
    qty = (session[:cart] || { "qty" => 0 })["qty"].to_i # { "qty" => 0 } Används bara första gången någon använder kundvagnen på hemsidan, den säger att det finns en tom kundvagn, därefter används session[:cart] eftersom vi har skapat en kundvagn då, utan { "qty" => 0 } skulle vi fått error message, däremot går den inte att använda efter det eftersom vi hela tiden skulle haft en tom kundvagn då
    qty = cart_qty
    halt 400, "Tom kundvagn" if qty <= 0 #400 = "Bad Request" error message, 404 ="Not Found" error message

    unit_price_ore = 44_900
    total_ore = qty * unit_price_ore #total = real summa

    name  = params[:name].to_s.strip
    email = params[:email].to_s.strip

    #db.execute(
      #"INSERT INTO orders (name, email, qty, total_ore) VALUES (?, ?, ?, ?)",
      #[name, email, qty, total_ore]
    #)

    Order.create(name, email, qty, total_ore)

    cart["qty"] = 0
    erb (:"/order/order_thanks")
  end

  get "/login" do 
    erb (:"/user/login")
  end

  post "/login" do
    #user = db.execute("SELECT * FROM users WHERE username = ?", [params[:username]]).first
    user = User.find_by_username(params[:username].to_s.strip)

    unless user
      status 401
      redirect "/user/acces_denied"
    end

    db_id = user["id"].to_i
    db_password_hashed = user["password"].to_s

    bcrypt_db_password = BCrypt::Password.new(db_password_hashed)

    if bcrypt_db_password == params[:password]
      session[:user_id] = db_id
      redirect "/"
    else
      p "fel användarnamn eller lösenord"
      redirect "/user/acces_denied"
    end
  end

  get "/user/acces_denied" do
    erb (:"/user/acces_denied")
  end

  post "/logout" do
    session.clear
    redirect "/"
  end

  #post "/webhook" do

  #end

end
