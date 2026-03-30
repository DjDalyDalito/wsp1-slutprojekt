class User
  def self.find_by_username(username)
    DB.execute(
      "SELECT * FROM users WHERE username = ?",
      [username]
    ).first
  end

  def self.authenticate(username, password)
    user = find_by_username(username)
    return false unless user

    BCrypt::Password.new(user["password"]) == password
  end
end