# db/seeder.rb
require 'sqlite3'
require_relative '../config'

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
  end

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
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        qty INTEGER NOT NULL DEFAULT 1,
        total_ore INTEGER NOT NULL,
        payment_status TEXT NOT NULL DEFAULT 'created',
        
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))

      );
    SQL
  end

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

    # Demo order
    db.execute(
      'INSERT INTO orders (name, email, qty, total_ore) VALUES (?, ?, ?, ?)',
      ["Demo Kund", "demo@demo.se", 1, 44_900]
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
