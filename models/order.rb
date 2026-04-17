class Order
  def self.create(name, email, qty, total_ore)
    DB.execute(
      "INSERT INTO orders (name, email, qty, total_ore) VALUES (?, ?, ?, ?)",
      [name, email, qty, total_ore]
    )
  end
  def self.find_by_id(id)
    DB.execute(
      "SELECT * FROM orders WHERE id = ?",
      [id]
    ).first
  end
end