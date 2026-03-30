require "stripe"

class App < Sinatra::Base
  PRICE_ORE = 44_900

  configure do
    set :app_url, ENV.fetch("APP_URL", "http://localhost:9292")
    set :stripe_webhook_secret, ENV.fetch("STRIPE_WEBHOOK_SECRET")
    Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY")
  end

  post "/checkout" do
    qty = cart_qty
    halt 400, "Tom kundvagn" if qty <= 0

    name, email = %w[name email].map { |k| params[k].to_s.strip }
    halt 400, "Namn saknas" if name.empty?
    halt 400, "Email saknas" if email.empty?

    total_ore = qty * PRICE_ORE
    db.execute("INSERT INTO orders (name, email, qty, total_ore) VALUES (?, ?, ?, ?)", [name, email, qty, total_ore])
    order_id = db.last_insert_row_id

    session = Stripe::Checkout::Session.create(
      mode: "payment",
      client_reference_id: order_id.to_s,
      customer_email: email,
      metadata: { order_id: order_id.to_s },
      line_items: [{
        price_data: {
          currency: "sek",
          product_data: { name: "TyperBuddy" },
          unit_amount: PRICE_ORE
        },
        quantity: qty
      }],
      success_url: "#{settings.app_url}/order/success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "#{settings.app_url}/order/cancel"
    )

    db.execute("UPDATE orders SET stripe_session_id = ?, updated_at = datetime('now') WHERE id = ?", [session.id, order_id])
    redirect session.url, 303
  end

  get "/order/success" do
    session_id = params[:session_id].to_s
    halt 400, "Session saknas" if session_id.empty?

    @checkout_session = Stripe::Checkout::Session.retrieve(session_id)
    @order = db.get_first_row("SELECT * FROM orders WHERE stripe_session_id = ?", [session_id])

    mark_paid(session_id, @checkout_session.payment_intent) if @checkout_session.payment_status == "paid"
    cart["qty"] = 0
    erb :order_success
  end

  get("/order/cancel") { erb :order_cancel }

  post "/webhook" do
    event = Stripe::Webhook.construct_event(
      request.body.read,
      request.env["HTTP_STRIPE_SIGNATURE"],
      settings.stripe_webhook_secret
    )

    session = event.data.object
    mark_paid(session.id, session.payment_intent) if event.type == "checkout.session.completed"

    if event.type == "checkout.session.expired"
      db.execute(
        "UPDATE orders SET payment_status = ?, updated_at = datetime('now') WHERE stripe_session_id = ? AND payment_status = ?",
        ["expired", session.id, "created"]
      )
    end

    ""
  rescue JSON::ParserError, Stripe::SignatureVerificationError
    halt 400, "Ogiltig webhook"
  end

  def mark_paid(session_id, payment_intent)
    db.execute(
      "UPDATE orders
       SET payment_status = ?, stripe_payment_intent_id = ?, paid_at = datetime('now'), updated_at = datetime('now')
       WHERE stripe_session_id = ? AND payment_status != ?",
      ["paid", payment_intent, session_id, "paid"]
    )
  end
end