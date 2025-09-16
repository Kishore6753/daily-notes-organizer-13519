-- Daily Notes Organizer - Initial MySQL Schema (DDL)
-- This file can be executed in MySQL CLI to create the database objects.
-- It aligns with assets/style_guide.md and component/page notes for fields.

-- Notes:
-- - Uses utf8mb4 for full Unicode (including emoji).
-- - InnoDB engine for FK constraints and transactions.
-- - Adds supporting indexes for common queries (CRUD, tagging, search).
-- - Includes unique constraints and ON DELETE behaviors aligned to app logic.
-- - Includes created_at / updated_at auto-management via DEFAULT/CURRENT_TIMESTAMP.

-- Ensure you are using the correct database before running.
-- Example: mysql -u appuser -pdbuser123 -h localhost -P 5000 myapp < schema.sql

-- 1) Users table
DROP TABLE IF EXISTS users;
CREATE TABLE users (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  username      VARCHAR(50) NOT NULL,
  email         VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NULL, -- leave nullable for early phases if auth not finalized
  avatar_url    VARCHAR(512) NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (id),
  UNIQUE KEY uq_users_username (username),
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2) Tags table
-- name: tag label (e.g., "work", "personal"); color: hex or token (e.g., "#6C8BFF")
DROP TABLE IF EXISTS tags;
CREATE TABLE tags (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name       VARCHAR(64) NOT NULL,
  color      VARCHAR(32) NULL, -- store hex or token name from style guide
  user_id    BIGINT UNSIGNED NULL, -- optional user-owned tags; NULL => global/shared
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (id),
  UNIQUE KEY uq_tags_name_user (name, user_id), -- tag name unique per user; allows global duplicates when scoped to different users
  KEY idx_tags_user_id (user_id),
  CONSTRAINT fk_tags_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3) Notes table
-- Fields: title, body, completion status, timestamps, user_id
-- completion_status: normalized as ENUM for simple filtering in UI
DROP TABLE IF EXISTS notes;
CREATE TABLE notes (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id            BIGINT UNSIGNED NOT NULL,
  title              VARCHAR(200) NOT NULL,
  body               MEDIUMTEXT NULL,
  completion_status  ENUM('not_started', 'in_progress', 'completed') NOT NULL DEFAULT 'not_started',
  is_archived        TINYINT(1) NOT NULL DEFAULT 0, -- for future archive behavior
  created_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (id),
  KEY idx_notes_user_id (user_id),
  KEY idx_notes_status (completion_status),
  KEY idx_notes_created_at (created_at),
  KEY idx_notes_updated_at (updated_at),
  -- Basic title index for quick LIKE prefix matches; for richer search, see FULLTEXT below
  KEY idx_notes_title (title),
  CONSTRAINT fk_notes_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Optional FULLTEXT to support search on title/body (MySQL 5.6+ InnoDB supports FULLTEXT)
-- Useful for search bar functionality (natural language or boolean mode).
-- Comment out if your MySQL variant doesn't allow FULLTEXT on InnoDB.
ALTER TABLE notes
  ADD FULLTEXT KEY ft_notes_title_body (title, body);

-- 4) NoteTags association table (many-to-many between notes and tags)
DROP TABLE IF EXISTS note_tags;
CREATE TABLE note_tags (
  note_id BIGINT UNSIGNED NOT NULL,
  tag_id  BIGINT UNSIGNED NOT NULL,
  -- Optional: position or metadata can be added later
  PRIMARY KEY (note_id, tag_id),
  KEY idx_note_tags_tag_id (tag_id),
  CONSTRAINT fk_note_tags_note
    FOREIGN KEY (note_id) REFERENCES notes(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_note_tags_tag
    FOREIGN KEY (tag_id) REFERENCES tags(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5) Supporting views (optional, can help debugging or simple analytics)

-- View: notes_with_user shows note with its user and status flags.
DROP VIEW IF EXISTS v_notes_with_user;
CREATE VIEW v_notes_with_user AS
SELECT
  n.id,
  n.title,
  n.body,
  n.completion_status,
  n.is_archived,
  n.created_at,
  n.updated_at,
  u.id   AS user_id,
  u.username,
  u.email
FROM notes n
JOIN users u ON u.id = n.user_id;

-- View: note with aggregated tag names (comma separated) - useful for quick listings
DROP VIEW IF EXISTS v_notes_with_tags;
CREATE VIEW v_notes_with_tags AS
SELECT
  n.id,
  n.user_id,
  n.title,
  n.completion_status,
  n.created_at,
  n.updated_at,
  GROUP_CONCAT(t.name ORDER BY t.name SEPARATOR ',') AS tags
FROM notes n
LEFT JOIN note_tags nt ON nt.note_id = n.id
LEFT JOIN tags t ON t.id = nt.tag_id
GROUP BY n.id, n.user_id, n.title, n.completion_status, n.created_at, n.updated_at;

-- 6) Seed data (minimal, optional; safe defaults for development)
-- Comment out if you prefer a clean start.

INSERT INTO users (username, email, password_hash)
VALUES
  ('demo', 'demo@example.com', NULL)
ON DUPLICATE KEY UPDATE email = VALUES(email);

-- Reference user_id for tags/notes seed
SET @demo_user_id = (SELECT id FROM users WHERE username = 'demo' LIMIT 1);

INSERT INTO tags (name, color, user_id)
VALUES
  ('work', '#6C8BFF', @demo_user_id),
  ('personal', '#22C55E', @demo_user_id)
ON DUPLICATE KEY UPDATE color = VALUES(color);

INSERT INTO notes (user_id, title, body, completion_status)
VALUES
  (@demo_user_id, 'Welcome to Daily Notes', 'Start capturing your day-to-day notes and tag them!', 'in_progress'),
  (@demo_user_id, 'Try tagging this note', 'Use tags like work and personal to organize.', 'not_started')
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

-- Link tags to notes (id lookups)
SET @note1 := (SELECT id FROM notes WHERE title = 'Welcome to Daily Notes' AND user_id = @demo_user_id LIMIT 1);
SET @note2 := (SELECT id FROM notes WHERE title = 'Try tagging this note' AND user_id = @demo_user_id LIMIT 1);
SET @tag_work := (SELECT id FROM tags WHERE name = 'work' AND user_id = @demo_user_id LIMIT 1);
SET @tag_personal := (SELECT id FROM tags WHERE name = 'personal' AND user_id = @demo_user_id LIMIT 1);

INSERT IGNORE INTO note_tags (note_id, tag_id) VALUES
  (@note1, @tag_work),
  (@note2, @tag_personal);

-- 7) Helpful query examples (for backend developers)

-- Search examples:
-- SELECT id, title FROM notes WHERE MATCH(title, body) AGAINST ('+tag* +organize' IN BOOLEAN MODE) LIMIT 20;
-- SELECT id, title FROM notes WHERE title LIKE 'Welc%' ORDER BY updated_at DESC LIMIT 20;

-- Tag filtering:
-- Find notes for a user with a specific tag:
-- SELECT n.* FROM notes n
-- JOIN note_tags nt ON nt.note_id = n.id
-- JOIN tags t ON t.id = nt.tag_id
-- WHERE n.user_id = @demo_user_id AND t.name = 'work';

-- Status filtering:
-- SELECT * FROM notes WHERE user_id = @demo_user_id AND completion_status = 'completed' ORDER BY updated_at DESC;

-- End of schema
