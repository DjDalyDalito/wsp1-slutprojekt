class User
  def self.find_by_username(username)
    DB.execute(
      "SELECT * FROM users WHERE username = ?",
      [username]
    ).first
  end

  def self.create(username, password)
    hashed_password = BCrypt::Password.create(password)

    DB.execute(
      "INSERT INTO users (username, password) VALUES (?, ?)",
      [username, hashed_password]
    )
  end
end