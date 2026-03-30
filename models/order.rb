class Order
  def self.create(name, email, qty, total_ore)
    DB.execute(
      "INSERT INTO orders (name, email, qty, total_ore) VALUES (?, ?, ?, ?)",
      [name, email, qty, total_ore]
    )
  end
end