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

#Huvudklass för applikationen.
#Hanterar routes, sessions, inloggning, kundvagn, meddelanden och ordrar
class App < Sinatra::Base

  configure do #configure => körs när appen (sinatra) startas
    set :sessions, true #aktiverar sessions i sinatra så att data kan sparas i en cookie i webbläsaren så t.ex "session[:cart] = { "qty" => 2 }" => kunden behåller sin kundvagn när de byter sida
    #set :stripe_webhook_secret, ENV["STRIPE_WEBHOOK_SECRET"]
    set :session_secret, "1234567890123456789012345678901234567890123456789012345678901234"#signerar cookien så att vem som helst inte kan ändra den
  end

  MAX_LOGIN_ATTEMPTS = 3
  LOCK_TIME = 60

 #Stripe.api_key = ENV.fetch['STRIPE_SECRET_KEY']

  #configure :development do
   # register Sinatra::Reloader #så man slipper starta om servern
  #end

  def db
    return @db if @db
    @db = SQLite3::Database.new(DB_PATH)
    @db.results_as_hash = true
    @db
  end

  helpers do

    #Konverterar öre till kronor i textformat
    #@param ore [Integer] pris i öre
    #@return [String] pris formaterat som kronor
    def money_kr(ore) #används i cart.erb, detta är den bästa lösningen jag kan komma på i stunden.
      kr = ore.to_i / 100.0
      format("%.0f kr", kr) #convertar tal till sträng utan decimaler, och lägg till suffix kr 
    end

    #Hämtar kundvagnen från sessionen eller skapar en tom kundvagn.
    #@return [Hash] kundvagnen
    def cart
      session[:cart] ||= { "qty" => 0 }
    end

    #Hämtar antal produkter i kundvagnen
    #@return [Integer] antal produkter
    def cart_qty
      cart["qty"].to_i
    end

    #Kontrollerar om användaren är inloggad
    #@return [Boolean] true om användaren är inloggad, annars false
    def logged_in?
      !!session[:user_id] #!! gör att det blir en boolean, om session[:user_id] har ett värde så blir det true annars false
    end

    #Hämtar antal misslyckade inloggningsförsök från sessionen
    #@return [Integer] antal försök
    def login_attempts
      session[:login_attempts] ||= 0
    end

    #Hämtar tiden då inloggningslåset upphör
    #@return [Integer, nil] unix-tid för låsningens slut eller nil
    def login_locked_until
      session[:login_locked_until] #hämtar tiden då låsningen ska sluta
    end

    #Kontrollerar om användaren är tillfälligt låst från att logga in
    #@return [Boolean] true om användaren är låst, annars false
    def login_locked?
      login_locked_until && Time.now.to_i < login_locked_until #finns det en sparad låsningstid och är nuvarande tid mindre än den tiden isf true good to go
    end


    #Kontrollerar om den inloggade användaren är administratör
    #@return [Boolean] true om användaren är admin, annars false
    def admin?
      logged_in? && current_user["role"] == "admin"  # Kollar om användaren är inloggad och om de är en admin
    end

    #Hämtar den inloggade användaren från databasen
    #@return [Hash, nil] användardata eller nil
    def current_user
      @current_user ||= DB.execute("SELECT * FROM users WHERE id = ?", [session[:user_id]]).first
    end

  end

  before do
    @logged_in = logged_in? #@logged_in är en instansvariabel som kan användas i alla views o den sätts till true eller false beroende på om användaren är inloggad eller inte
  end

  #Skyddar routes så att endast inloggade användare får åtkomst
  #@return [void]
  def protected!
    redirect "/login" unless logged_in? #om inte logged_in? så skickas användaren till login-sidan
  end

  #Visar startsidan
  #@route GET /
  #@return [String] renderar startsidan
  get "/" do
    erb (:"/main/index")
  end

  #Tar emot och sparar ett kontaktmeddelande
  #@route POST /message
  #@param name [String] avsändarens namn
  #@param email [String] avsändarens e-postadress
  #@param subject [String] meddelandets ämne
  #@param message [String] meddelandets innehåll
  #@return [String] tack-sida efter sparat meddelande
  post "/message" do
    name = params[:name].to_s.strip
    email = params[:email].to_s.strip
    subject = params[:subject].to_s.strip
    message = params[:message].to_s.strip

    #db.execute(
      #"INSERT INTO messages (name, email, subject, message) VALUES (?, ?, ?, ?)",
      #[name, email, subject, message]
    #)

    halt 404, "Namn får inte vara tomt" if name.empty?
    halt 404, "Email måste innehålla gmail.com" unless email.include?("gmail.com")
    halt 404, "Meddelandet är för långt" if message.length > 500

    @message_id = Message.create(name, email, subject, message)
    erb (:"/message/thanks")
  end

  #Lägger till en produkt i kundvagnen
  #@route POST /cart/new
  #@return [void] omdirigerar till kundvagnen
  post "/cart/new" do
    #session[:cart] ||= { "qty" => 0} # "||=" om det inte redan finns något värde här, sätt till detta ___.
    #session[:cart]["qty"] = session[:cart]["qty"].to_i + 1 
    cart["qty"] = cart_qty + 1
    redirect "/order/cart"
  end

  #Tar bort en produkt från kundvagnen
  #@route POST /cart/delete
  #@return [void] omdirigerar till kundvagnen
  post "/cart/delete" do
    #session[:cart] ||= { "qty" => 0}
    #session[:cart]["qty"] = [session[:cart]["qty"].to_i - 1, 0].max #kan aldrig bli ett negativt värde därav , 0 och .max
    cart["qty"] = [cart_qty - 1, 0].max
    redirect "/order/cart"
  end

  #Visar kundvagnen för inloggad användare
  #@route GET /order/cart
  #@return [String] renderar kundvagnssidan
  get "/order/cart" do
    protected! #för att komma till kundvagnen måste man vara inloggad, annars skickas man till login-sidan
    #qty = session[:cart] ||= { "qty" => 0}
    #@qty = qty["qty"].to_i #@ = instansvariabel, @-variabler (instansvariabler) används när du vill skicka data till din erb-view, medan vanliga variabler utan @ bara behövs inne i routen
    @qty = cart_qty
    unit_price_ore = 44_900
    @subtotal_ore = @qty * unit_price_ore #subtotal = delsumma, fake
    erb (:"/order/cart")
  end

  #Genomför checkout och skapar en order
  #@route POST /checkout
  #@param name [String] kundens namn
  #@param email [String] kundens e-postadress
  #@return [void] omdirigerar till ordersidan
  post "/checkout" do
    protected!
    qty = (session[:cart] || { "qty" => 0 })["qty"].to_i # { "qty" => 0 } Används bara första gången någon använder kundvagnen på hemsidan, den säger att det finns en tom kundvagn, därefter används session[:cart] eftersom vi har skapat en kundvagn då, utan { "qty" => 0 } skulle vi fått error message, däremot går den inte att använda efter det eftersom vi hela tiden skulle haft en tom kundvagn då
    qty = cart_qty
    halt 404, "Tom kundvagn" if qty <= 0

    unit_price_ore = 44_900
    total_ore = qty * unit_price_ore #total = real summa

    name  = params[:name].to_s.strip
    email = params[:email].to_s.strip

    #db.execute(
      #"INSERT INTO orders (name, email, qty, total_ore) VALUES (?, ?, ?, ?)",
      #[name, email, qty, total_ore]
    #)

    order_id = Order.create(session[:user_id], name, email, qty, total_ore)

    cart["qty"] = 0
    redirect "/orders/#{order_id}"
  end

  #Visar inloggningssidan
  #@route GET /login
  #@return [String] renderar login-sidan
  get "/login" do 
    erb (:"/user/login")
  end

  #Loggar in en användare
  #@route POST /login
  #@param username [String] användarnamn
  #@param password [String] lösenord
  #@return [void] omdirigerar beroende på resultat
  post "/login" do
  if login_locked?
    puts "Failad login: #{params[:username]} från #{request.ip}"
    halt 404, "För många försök. Vänta 60 sekunder."
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

  #Visar sida för nekad åtkomst
  #@route GET /user/acces_denied
  #@return [String] renderar fel-sidan
  get "/user/acces_denied" do
    erb (:"/user/acces_denied")
  end

  #Loggar ut den inloggade användaren
  #@route POST /logout
  #@return [void] omdirigerar till startsidan
  post "/logout" do
    protected!
    session.clear
    redirect "/"
  end

  #Visar registreringssidan
  #@route GET /register
  #@return [String] renderar registreringssidan
  get "/register" do
    erb (:"/user/register")
  end

  #Registrerar en ny användare
  #@route POST /register
  #@param username [String] användarnamn
  #@param password [String] lösenord
  #@return [void] omdirigerar till login-sidan
  post "/register" do
    username = params[:username].to_s.strip
    password = params[:password].to_s
    halt 404, "Användarnamn måste vara minst 6 tecken" if username.length < 6
    halt 404, "Lösenord måste vara minst 6 tecken" if password.length < 6
    User.create(username, password)
    redirect "/login"
  end

  #Visar en specifik order
  #@route GET /orders/:id
  #@param id [String] orderns id
  #@return [String] renderar order-sidan
  get "/orders/:id" do |id|
    protected!
    @order = Order.find_by_id(id)
    halt 404, "Ordern finns inte" unless @order
    halt 404, "Du har inte tillgång till denna order" unless @order["user_id"] == session[:user_id]
    erb(:"/order/show")
  end

  #Tar bort en specifik order
  #@route POST /orders/:id/delete
  #@param id [String] orderns id
  #@return [void] omdirigerar till startsidan
  post "/orders/:id/delete" do |id|
    protected!
    order = Order.find_by_id(id)
    halt 404, "Ordern finns inte" unless order
    halt 404, "Du har inte tillgång till denna order" unless order["user_id"] == session[:user_id]
    Order.delete(id)
    redirect "/"
  end

  #Visar alla meddelanden för administratörer
  #@route GET /admin/message
  #@return [String] renderar admin-sidan för meddelanden
  get "/admin/message" do
    protected!
    halt 404, "Endast administratörer har tillgång" unless admin?
    @messages = DB.execute("SELECT * FROM messages")
    erb :"admin/messages"
  end

  #Tar bort ett specifikt meddelande
  #@route POST /message/:id/delete
  #@param id [String] meddelandets id
  #@return [void] omdirigerar till startsidan
  post "/message/:id/delete" do |id|
    protected!
    message = Message.find_by_id(id)
    halt 404, "Meddelandet finns inte" unless message
    Message.delete(id)
    redirect "/"
  end

  #post "/webhook" do

  #end

end
