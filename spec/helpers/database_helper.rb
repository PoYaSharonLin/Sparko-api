# frozen_string_literal: true

# Helper to clean database during test runs
module DatabaseHelper
  def self.wipe_database
    # Ignore foreign key constraints when wiping tables
    Sparko::App.db.run('PRAGMA foreign_keys = OFF')
    Sparko::Database::PaperOrm.map(&:destroy)
    Sparko::Database::AuthorOrm.map(&:destroy)
    Sparko::Database::CategoryOrm.map(&:destroy)
    Sparko::App.db.run('PRAGMA foreign_keys = ON')
  end
end
