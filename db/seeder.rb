# db/seeder.rb
require 'sqlite3'
require_relative '../config'
require "bcrypt"

class Seeder
  def self.seed!
    puts "Using db file: #{DB_PATH}"
    puts "🧹 Dropping old tables..."
    drop_tables
    puts "🧱 Creating tables..."
    create_tables
    puts "🍎 Populating tables..."
    populate_tables
    puts "✅ Done seeding the database!"
  end

  def self.drop_tables
    db.execute('DROP TABLE IF EXISTS messages')
    db.execute('DROP TABLE IF EXISTS orders')
    db.execute('DROP TABLE IF EXISTS users')
    db.execute('DROP TABLE IF EXISTS order_items')
    db.execute('DROP TABLE IF EXISTS products')
  end

  #mångatmånga 
  #order items vad som säljs
  #orders själv köpet
  #produkt vad som säljs
  #users vem som gör själva köpet
  #så att databasen kan lagra produkter separat och sedan återanvända dem i andra beställningar då slipper vi skriva produktnamn direkt i varje order

  def self.create_tables
    db.execute <<~SQL
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        subject TEXT,
        message TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    SQL
    
    db.execute <<~SQL
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price_ore INTEGER NOT NULL
      );
    SQL

    db.execute <<~SQL
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        failed_attempts INTEGER NOT NULL DEFAULT 0,
        locked_until TEXT
      );
    SQL

    db.execute <<~SQL
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        qty INTEGER NOT NULL DEFAULT 1,
        total_ore INTEGER NOT NULL,
        payment_status TEXT NOT NULL DEFAULT 'created',
        stripe_session_id TEXT UNIQUE,
        stripe_payment_intent_id TEXT,
        paid_at TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      );
    SQL
    #ON DELETE CASCADE för om en userid tas bort så ska allting med den usern att göra tas bort 

    db.execute <<~SQL
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        item_price_ore INTEGER NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
      );
    SQL
  end

  #Databasen innehåller flera tabeller och en många-till-många-relation mellan orders och products som hanteras med relationstabellen order_items, (däremot hanteras inte messages med relationstabellen)

  def self.populate_tables
    # Demo messages
    db.execute(
      'INSERT INTO messages (name, email, subject, message) VALUES (?, ?, ?, ?)',
      ["Anna L", "anna@example.com", "Fråga", "Hur lång är leveransen?"]
    )
    db.execute(
      'INSERT INTO messages (name, email, subject, message) VALUES (?, ?, ?, ?)',
      ["Erik H", "erik@example.com", "Support", "Kan jag returnera inom 30 dagar?"]
    )

    #produkt
    db.execute(
      'INSERT INTO products (name, price_ore) VALUES (?, ?)',
      ['BootingKeyboard', 4490]
    )

    #orderprodukt
    db.execute(
      'INSERT INTO order_items (order_id, product_id, quantity, item_price_ore) VALUES (?, ?, ?, ?)',
      [1, 1, 1, 4490]
    )

    # Demo order
    db.execute(
      'INSERT INTO orders (user_id, name, email, qty, total_ore) VALUES (?, ?, ?, ?, ?)',
      [1, "Demo Kund", "demo@demo.se", 1, 44_900]
    )

    hashed_password = BCrypt::Password.create("hejhejhej")

    db.execute(
      'INSERT INTO users (username, password) VALUES (?, ?)',
      ["hejhejhej", hashed_password]
    )
  end

  private

  def self.db
    @db ||= begin
      db = SQLite3::Database.new(DB_PATH)
      db.results_as_hash = true

      db
    end
  end
end

Seeder.seed!
