require "sinatra/base"
require "sinatra/reloader" if development?
require_relative "./config"
require "json"
require "sqlite3"
require "stripe"

class App < Sinatra::Base

  configure do #configure => körs när appen (sinatra) startas
    set :sessions, true #aktiverar sessions i sinatra så att data kan sparas i en cookie i webbläsaren så t.ex "session[:cart] = { "qty" => 2 }" => kunden behåller sin kundvagn när de byter sida
    set :stripe_webhook_secret, ENV["STRIPE_WEBHOOK_SECRET"]
  end

  Stripe.api_key = ENV.fetch['STRIPE_SECRET_KEY']

  configure :development do #så man slipper starta om servern varje gång smart.
    register Sinatra::Reloader
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

  end

  get "/" do
    erb :index
  end

  post "/kontakt" do
    name = params[:name].to_s.strip
    email = params[:email].to_s.strip
    subject = params[:subject].to_s.strip
    message = params[:message].to_s.strip

    db.execute(
      "INSERT INTO messages (name, email, subject, message) VALUES (?, ?, ?, ?)",
      [name, email, subject, message]
    )

    erb :thanks
  end

  post "/cart/add" do
    #session[:cart] ||= { "qty" => 0} # "||=" om det inte redan finns något värde här, sätt till detta ___.
    #session[:cart]["qty"] = session[:cart]["qty"].to_i + 1 
    cart["qty"] = cart_qty + 1
    redirect "/cart"
  end

  post "/cart/remove" do
    #session[:cart] ||= { "qty" => 0}
    #session[:cart]["qty"] = [session[:cart]["qty"].to_i - 1, 0].max #kan aldrig bli ett negativt värde därav , 0 och .max
    cart["qty"] = [cart_qty - 1, 0].max
    redirect "/cart"
  end

  get "/cart" do
    #qty = session[:cart] ||= { "qty" => 0}
    #@qty = qty["qty"].to_i #@ = instansvariabel, @-variabler (instansvariabler) används när du vill skicka data till din erb-view, medan vanliga variabler utan @ bara behövs inne i routen
    @qty = cart_qty
    unit_price_ore = 44_900
    @subtotal_ore = @qty * unit_price_ore #subtotal = delsumma, fake
    erb :cart
  end

  post "/checkout" do
    #qty = (session[:cart] || { "qty" => 0 })["qty"].to_i # { "qty" => 0 } Används bara första gången någon använder kundvagnen på hemsidan, den säger att det finns en tom kundvagn, därefter används session[:cart] eftersom vi har skapat en kundvagn då, utan { "qty" => 0 } skulle vi fått error message, däremot går den inte att använda efter det eftersom vi hela tiden skulle haft en tom kundvagn då
    qty = cart_qty
    halt 400, "Tom kundvagn" if qty <= 0 #400 = "Bad Request" error message, 404 ="Not Found" error message

    unit_price_ore = 44_900
    total_ore = qty * unit_price_ore #total = real summa

    name  = params[:name].to_s.strip
    email = params[:email].to_s.strip

    db.execute(
      "INSERT INTO orders (name, email, qty, total_ore) VALUES (?, ?, ?, ?)",
      [name, email, qty, total_ore]
    )

    cart["qty"] = 0
    erb :order_thanks
  end

  #post "/webhook" do

  #end

end
