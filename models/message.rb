class Message
  def self.create(name, email, subject, message)
    DB.execute(
      "INSERT INTO messages (name, email, subject, message) VALUES (?, ?, ?, ?)",
      [name, email, subject, message]
    )
  end
end