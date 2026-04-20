class Message
  def self.create(name, email, subject, message)
    DB.execute(
      "INSERT INTO messages (name, email, subject, message) VALUES (?, ?, ?, ?)",
      [name, email, subject, message]
    )
    DB.last_insert_row_id
  end
  def self.delete(id)
    DB.execute("DELETE FROM messages WHERE id = ?", [id])
  end
  def self.find_by_id(id)
    DB.execute("SELECT * FROM messages WHERE id = ?", [id]).first
  end
end