require 'sqlite3'
require 'fileutils'

DB_NAME   = 'sqlite.db'
DB_FOLDER = 'db'
DB_PATH   = File.join(__dir__, DB_FOLDER, DB_NAME)

FileUtils.mkdir_p(File.join(__dir__, DB_FOLDER))