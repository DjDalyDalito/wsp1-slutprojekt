require "sinatra/base"
require "sinatra/activerecord"

class Message < ActiveRecord::Base # message kommer att ha tillgång till alla metoder och funktioner som ActiveRecord håller för att hantera databaser som att spara, uppdatera och radera objekt i databasen
  validates :name, :email, :message, presence: true # säkerställer (mha validate presence: true) att ingen av dem tre attributen name, email, och message får vara tomma när ett objekt skapas, då kommer objektet inte att sparas i databasen och ett felmeddelande dyker upp
end

class App < Sinatra::Base
  register Sinatra::ActiveRecordExtension

  configure do #configure => körs när appen (sinatra) startas
    set :database, { adapter: "sqlite3", database: DB_PATH }
  end

  helpers do

    def unit_price_ore
      44_900
    end

    def money_kr(ore)
      kr = ore.to_i / 100.0
      format("%.0f kr", kr) #convertar tal till sträng utan decimaler, och lägg till suffix kr 
    end

  end

  get "/" do
    erb :index
  end

  post "/kontakt" do
    msg = Message.new(
      name: params[:name].to_s.strip,
      email: params[:email].to_s.strip,
      subject: params[:subject].to_s.strip,
      message: params[:message].to_s.strip
    )

    if msg.save #.save från activerecord, försöker spara objektet till databasen
      erb :thanks
    else
      @errors = msg.errors.full_messages #. också från activerecord, samlar alla errorfel för objektet
      erb :index
    end
  end

  post "/cart/add" do
    session[:cart] ||= { "qty" => 0} # "||=" om det inte redan finns något värde här, sätt till detta ___.
    session[:cart]["qty"] = session[:cart]["qty"].to_i + 1 
    redirect "/cart"
  end

  post "/cart/remove" do
    session[:cart] ||= { "qty" => 0}
    session[:cart]["qty"] = [session[:cart]["qty"].to_i - 1, 0].max #kan aldrig bli ett negativt värde därav , 0 och .max
    redirect "/cart"
  end

  get "/cart" do
    qty = session[:cart] ||= { "qty" => 0}
    @qty = qty["qty"].to_i #@ = instansvariabel
    @subtotal_ore = @qty * 44_990
    erb :cart
  end

  #get "/thanks" do

  #end

  #post "/checkout" do

  #end

end
