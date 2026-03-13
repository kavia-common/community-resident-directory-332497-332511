-- Resident Directory - Initial Schema
-- This migration is intended to be applied by scripts/migrate.sh.
-- It is written to be idempotent where practical (IF NOT EXISTS), but
-- schema changes should still be done via new migrations.

BEGIN;

-- Enable extensions commonly used for IDs and case-insensitive email
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";

-- Core: App users/auth
CREATE TABLE IF NOT EXISTS app_user (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email               citext NOT NULL UNIQUE,
    password_hash       text, -- nullable for external auth/OIDC
    auth_provider       text NOT NULL DEFAULT 'local', -- local|oidc|auth0|...
    provider_subject    text, -- sub/uid from provider
    is_active           boolean NOT NULL DEFAULT true,
    is_admin            boolean NOT NULL DEFAULT false,
    display_name        text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    last_login_at       timestamptz
);

CREATE INDEX IF NOT EXISTS idx_app_user_provider_subject ON app_user(auth_provider, provider_subject);

-- Track roles more granularly (admin panel, moderation, etc.)
CREATE TABLE IF NOT EXISTS app_role (
    id          bigserial PRIMARY KEY,
    name        text NOT NULL UNIQUE,
    description text,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app_user_role (
    user_id     uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    role_id     bigint NOT NULL REFERENCES app_role(id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, role_id)
);

-- Residents/profiles (directory core)
CREATE TABLE IF NOT EXISTS resident_profile (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid UNIQUE REFERENCES app_user(id) ON DELETE SET NULL,
    full_name           text NOT NULL,
    unit                text, -- unit/apartment number
    address_line1       text,
    address_line2       text,
    city                text,
    state               text,
    postal_code         text,
    phone               text,
    email_public        citext, -- optional contact shown if privacy allows
    bio                 text,

    -- Photo metadata (store file externally; keep metadata here)
    photo_object_key    text, -- e.g., S3 key / storage path
    photo_filename      text,
    photo_content_type  text,
    photo_size_bytes    bigint,
    photo_width         integer,
    photo_height        integer,
    photo_uploaded_at   timestamptz,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_resident_profile_unit ON resident_profile(unit);
CREATE INDEX IF NOT EXISTS idx_resident_profile_full_name ON resident_profile(full_name);

-- Privacy settings per resident
CREATE TABLE IF NOT EXISTS resident_privacy_settings (
    resident_id                 uuid PRIMARY KEY REFERENCES resident_profile(id) ON DELETE CASCADE,
    show_phone                   boolean NOT NULL DEFAULT false,
    show_email                   boolean NOT NULL DEFAULT false,
    show_address                 boolean NOT NULL DEFAULT false,
    show_photo                   boolean NOT NULL DEFAULT true,
    allow_messages_from_residents boolean NOT NULL DEFAULT true,
    allow_messages_from_admins    boolean NOT NULL DEFAULT true,
    created_at                   timestamptz NOT NULL DEFAULT now(),
    updated_at                   timestamptz NOT NULL DEFAULT now()
);

-- Invitations / onboarding flow
CREATE TABLE IF NOT EXISTS invitation (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email               citext NOT NULL,
    invited_by_user_id  uuid REFERENCES app_user(id) ON DELETE SET NULL,
    token_hash          text NOT NULL UNIQUE, -- store hash only (never raw token)
    expires_at          timestamptz NOT NULL,
    accepted_at         timestamptz,
    revoked_at          timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT invitation_status_chk CHECK (
        (accepted_at IS NULL OR revoked_at IS NULL) -- cannot be both accepted and revoked
    )
);

CREATE INDEX IF NOT EXISTS idx_invitation_email ON invitation(email);
CREATE INDEX IF NOT EXISTS idx_invitation_expires_at ON invitation(expires_at);

CREATE TABLE IF NOT EXISTS onboarding_event (
    id              bigserial PRIMARY KEY,
    invitation_id   uuid REFERENCES invitation(id) ON DELETE CASCADE,
    user_id         uuid REFERENCES app_user(id) ON DELETE SET NULL,
    event_type      text NOT NULL, -- invited|email_sent|accepted|profile_created|...
    event_data      jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_onboarding_event_invitation ON onboarding_event(invitation_id);
CREATE INDEX IF NOT EXISTS idx_onboarding_event_user ON onboarding_event(user_id);

-- Announcements / messages
CREATE TABLE IF NOT EXISTS announcement (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    created_by      uuid REFERENCES app_user(id) ON DELETE SET NULL,
    title           text NOT NULL,
    body            text NOT NULL,
    is_pinned       boolean NOT NULL DEFAULT false,
    visibility      text NOT NULL DEFAULT 'all', -- all|residents|admins
    published_at    timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_announcement_published_at ON announcement(published_at);
CREATE INDEX IF NOT EXISTS idx_announcement_is_pinned ON announcement(is_pinned);

-- Direct messages between users (optional feature)
CREATE TABLE IF NOT EXISTS direct_message_thread (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS direct_message_thread_participant (
    thread_id   uuid NOT NULL REFERENCES direct_message_thread(id) ON DELETE CASCADE,
    user_id     uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (thread_id, user_id)
);

CREATE TABLE IF NOT EXISTS direct_message (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id       uuid NOT NULL REFERENCES direct_message_thread(id) ON DELETE CASCADE,
    sender_user_id  uuid REFERENCES app_user(id) ON DELETE SET NULL,
    body            text NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_direct_message_thread_created ON direct_message(thread_id, created_at);

-- Audit logs
CREATE TABLE IF NOT EXISTS audit_log (
    id              bigserial PRIMARY KEY,
    actor_user_id   uuid REFERENCES app_user(id) ON DELETE SET NULL,
    actor_email     citext, -- denormalized for convenience
    action          text NOT NULL, -- e.g., resident.create, invitation.revoke, auth.login
    entity_type     text, -- resident_profile|announcement|invitation|...
    entity_id       uuid,
    request_id      text, -- to correlate API requests
    ip_address      inet,
    user_agent      text,
    details         jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON audit_log(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_log_actor_user_id ON audit_log(actor_user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_entity ON audit_log(entity_type, entity_id);

-- Migration tracking
CREATE TABLE IF NOT EXISTS schema_migrations (
    version     text PRIMARY KEY,
    applied_at  timestamptz NOT NULL DEFAULT now()
);

COMMIT;
