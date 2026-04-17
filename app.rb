require "sinatra/base"
#require "sinatra/reloader" if development?
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
    set :session_secret, "1234567890123456789012345678901234567890123456789012345678901234"#signerar cookien så att vem som helst inte kan ändra den
  end

  MAX_LOGIN_ATTEMPTS = 3
  LOCK_TIME = 60

 #Stripe.api_key = ENV.fetch['STRIPE_SECRET_KEY']

  configure :development do
   # register Sinatra::Reloader #så man slipper starta om servern
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

    def login_attempts
      session[:login_attempts] ||= 0
    end

    def login_locked_until
      session[:login_locked_until] #hämtar tiden då låsningen ska sluta
    end

    def login_locked?
      login_locked_until && Time.now.to_i < login_locked_until #finns det en sparad låsningstid och är nuvarande tid mindre än den tiden isf true good to go
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
    name = params[:name].to_s.strip
    email = params[:email].to_s.strip
    subject = params[:subject].to_s.strip
    message = params[:message].to_s.strip

    #db.execute(
      #"INSERT INTO messages (name, email, subject, message) VALUES (?, ?, ?, ?)",
      #[name, email, subject, message]
    #)

    halt 400, "Namn får inte vara tomt" if name.empty?
    halt 400, "Email måste innehålla gmail.com" unless email.include?("gmail.com")
    halt 400, "Meddelandet är för långt" if message.length > 500

    Message.create(name, email, subject, message)

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
    protected!
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

    Order.create(session[:user_id], name, email, qty, total_ore)

    cart["qty"] = 0
    erb (:"/order/order_thanks")
  end

  get "/login" do 
    erb (:"/user/login")
  end

  post "/login" do
  if login_locked?
    puts "Failad login: #{params[:username]} från #{request.ip}"
    halt 429, "För många försök. Vänta 60 sekunder." #429=för många försök
  end
    #user = db.execute("SELECT * FROM users WHERE username = ?", [params[:username]]).first
    username = params[:username].to_s.strip
    password = params[:password].to_s #INTE STRIP PÅ LÖSENORD!!! det ska matcha exakt
    user = User.find_by_username(username)

    unless user
      session[:login_attempts] = login_attempts + 1
      puts "Failad login: #{username} från #{request.ip} (försök #{session[:login_attempts]})"

      if session[:login_attempts] >= MAX_LOGIN_ATTEMPTS
        session[:login_locked_until] = Time.now.to_i + LOCK_TIME
        puts "Failad login: #{username} från #{request.ip}"
      end
      redirect "/user/acces_denied"
    end

    db_id = user["id"].to_i
    db_password_hashed = user["password"].to_s

    bcrypt_db_password = BCrypt::Password.new(db_password_hashed)

    if bcrypt_db_password == password
      session[:user_id] = db_id
      puts "Lyckad login: #{username} from #{request.ip}"
      session[:login_attempts] = 0
      session[:login_locked_until] = nil
      redirect "/"
    else
      session[:login_attempts] = login_attempts + 1
      puts "Failad login: #{username} från #{request.ip} (försök #{session[:login_attempts]})"
      if session[:login_attempts] >= MAX_LOGIN_ATTEMPTS
        session[:login_locked_until] = Time.now.to_i + LOCK_TIME
        puts "Failad login: #{username} från #{request.ip}"
      end
      p "fel användarnamn eller lösenord"
      redirect "/user/acces_denied"
    end
  end

  get "/user/acces_denied" do
    erb (:"/user/acces_denied")
  end

  post "/logout" do
    protected!
    session.clear
    redirect "/"
  end

  get "/register" do
    erb (:"/user/register")
  end

  post "/register" do
    username = params[:username].to_s.strip
    password = params[:password].to_s

    halt 400, "Användarnamn måste vara minst 6 tecken" if username.length < 6
    halt 400, "Lösenord måste vara minst 6 tecken" if password.length < 6

    User.create(username, password)
    redirect "/login"
  end

  get "/orders/:id" do |id|
    protected!

    @order = Order.find_by_id(id)
    halt 404, "Ordern finns inte" unless @order
    halt 403, "Du har inte tillgång till denna order" unless @order["user_id"] == session[:user_id]

    erb(:"/order/show")
  end

  #post "/webhook" do

  #end

end
