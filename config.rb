require 'sqlite3'
require 'fileutils'

DB_NAME   = 'sqlite.db'
DB_FOLDER = 'db'
DB_PATH   = File.join(__dir__, DB_FOLDER, DB_NAME)

DB = SQLite3::Database.new(DB_PATH)
DB.results_as_hash = true

FileUtils.mkdir_p(File.join(__dir__, DB_FOLDER))