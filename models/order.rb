class Order
  def self.create(user_id, name, email, qty, total_ore)
    DB.execute(
      "INSERT INTO orders (user_id, name, email, qty, total_ore) VALUES (?, ?, ?, ?, ?)",
      [user_id, name, email, qty, total_ore]
    )
    DB.last_insert_row_id
  end
  def self.find_by_id(id)
    DB.execute(
      "SELECT * FROM orders WHERE id = ?",
      [id]
    ).first
  end
  def self.delete(id)
    DB.execute(
      "DELETE FROM orders WHERE id = ?",
      [id]
    )
  end
end