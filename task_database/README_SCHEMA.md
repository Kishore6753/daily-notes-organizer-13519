# Daily Notes Organizer — Database Schema

This folder contains the initial MySQL schema for the Daily Notes Organizer app.

Contents
- schema.sql — DDL for `users`, `tags`, `notes`, and `note_tags`, with indexes and constraints.

Key Tables
- users: username, email, password_hash, timestamps
- tags: name (unique per user), color, optional user_id (NULL => global)
- notes: title, body, completion_status (enum: not_started|in_progress|completed), timestamps, user_id
- note_tags: association (many-to-many) between notes and tags

Indexes and Search
- Fulltext index on notes(title, body) to support the search bar.
- Secondary indexes on user_id, status, timestamps for common filters and sorting.

Foreign Key Behavior
- notes.user_id -> users.id (ON DELETE CASCADE)
- tags.user_id -> users.id (ON DELETE SET NULL)
- note_tags.note_id -> notes.id (ON DELETE CASCADE)
- note_tags.tag_id -> tags.id (ON DELETE CASCADE)

How to Apply
1) Ensure MySQL is running. The repo includes a convenience startup script that configures:
   - DB: myapp
   - App user: appuser / dbuser123
   - Port: 5000

2) Run:
   - bash startup.sh
   - mysql -u appuser -pdbuser123 -h localhost -P 5000 myapp < schema.sql

3) Verify tables:
   - mysql -u appuser -pdbuser123 -h localhost -P 5000 myapp -e "SHOW TABLES;"

Seed Data
- A demo user and a couple of tags/notes are inserted to help local testing.
- Remove or comment the seed section for production SQL.

Notes
- Charset: utf8mb4 for proper Unicode/emoji support.
- Engine: InnoDB for transactional safety and FK constraints.

