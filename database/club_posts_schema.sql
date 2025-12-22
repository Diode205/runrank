-- Club Posts Database Schema
-- Execute these SQL commands in your Supabase SQL Editor

-- 1. Create club_posts table
CREATE TABLE IF NOT EXISTS club_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    image_url TEXT,
    is_approved BOOLEAN NOT NULL DEFAULT FALSE,
    expiry_date TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create club_post_kudos table (DEPRECATED - use reactions instead)
-- Kept for backward compatibility
CREATE TABLE IF NOT EXISTS club_post_kudos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES club_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

-- 2b. Create club_post_reactions table (PREFERRED - supports emojis)
CREATE TABLE IF NOT EXISTS club_post_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES club_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, user_id, emoji)
);

-- 3. Create club_post_comments table
CREATE TABLE IF NOT EXISTS club_post_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES club_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    comment TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3b. Attachments for posts
CREATE TABLE IF NOT EXISTS club_post_attachments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES club_posts(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- 'image' | 'link' | 'file'
    url TEXT NOT NULL,
    name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_club_posts_author ON club_posts(author_id);
CREATE INDEX IF NOT EXISTS idx_club_posts_expiry ON club_posts(expiry_date);
CREATE INDEX IF NOT EXISTS idx_club_posts_created ON club_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_club_post_kudos_post ON club_post_kudos(post_id);
CREATE INDEX IF NOT EXISTS idx_club_post_kudos_user ON club_post_kudos(user_id);
CREATE INDEX IF NOT EXISTS idx_club_post_reactions_post ON club_post_reactions(post_id);
CREATE INDEX IF NOT EXISTS idx_club_post_reactions_user ON club_post_reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_club_post_reactions_emoji ON club_post_reactions(emoji);
CREATE INDEX IF NOT EXISTS idx_club_post_comments_post ON club_post_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_club_post_comments_created ON club_post_comments(created_at);

-- 5. Enable Row Level Security (RLS)
ALTER TABLE club_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE club_post_kudos ENABLE ROW LEVEL SECURITY;
ALTER TABLE club_post_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE club_post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE club_post_attachments ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies for club_posts
-- Everyone can read posts
CREATE POLICY "Anyone can view posts"
    ON club_posts FOR SELECT
        USING (
            is_approved = true OR author_id = auth.uid()
        );

-- Only admins can create posts
-- Allow anyone to create posts; non-admins default to unapproved
CREATE POLICY "Anyone can create posts"
    ON club_posts FOR INSERT
    WITH CHECK (auth.uid() = author_id);

-- Only admins can update posts
CREATE POLICY "Admins can update posts"
    ON club_posts FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND is_admin = true
        )
    );

-- Only admins can delete posts
CREATE POLICY "Admins can delete posts"
    ON club_posts FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND is_admin = true
        )
    );

-- Attachments RLS
CREATE POLICY "Anyone can view attachments"
        ON club_post_attachments FOR SELECT
        USING (true);

CREATE POLICY "Authors add attachments"
        ON club_post_attachments FOR INSERT
        WITH CHECK (
            EXISTS (
                SELECT 1 FROM club_posts p WHERE p.id = post_id AND p.author_id = auth.uid()
            )
        );

CREATE POLICY "Authors delete attachments"
        ON club_post_attachments FOR DELETE
        USING (
            EXISTS (
                SELECT 1 FROM club_posts p WHERE p.id = post_id AND p.author_id = auth.uid()
            )
        );

-- 7. RLS Policies for club_post_kudos
-- Everyone can view kudos
CREATE POLICY "Anyone can view kudos"
    ON club_post_kudos FOR SELECT
    USING (true);

-- Users can add their own kudos
CREATE POLICY "Users can add kudos"
    ON club_post_kudos FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can delete their own kudos
CREATE POLICY "Users can remove their kudos"
    ON club_post_kudos FOR DELETE
    USING (auth.uid() = user_id);

-- 7b. RLS Policies for club_post_reactions (PREFERRED)
-- Everyone can view reactions
CREATE POLICY "Anyone can view reactions"
    ON club_post_reactions FOR SELECT
    USING (true);

-- Users can add their own reactions
CREATE POLICY "Users can add reactions"
    ON club_post_reactions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can delete their own reactions
CREATE POLICY "Users can remove their reactions"
    ON club_post_reactions FOR DELETE
    USING (auth.uid() = user_id);

-- 8. RLS Policies for club_post_comments
-- Everyone can view comments
CREATE POLICY "Anyone can view comments"
    ON club_post_comments FOR SELECT
    USING (true);

-- Users can add their own comments
CREATE POLICY "Users can add comments"
    ON club_post_comments FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can delete their own comments
CREATE POLICY "Users can delete their comments"
    ON club_post_comments FOR DELETE
    USING (auth.uid() = user_id);

-- 9. Create a function to auto-delete expired posts (optional scheduled cleanup)
CREATE OR REPLACE FUNCTION delete_expired_posts()
RETURNS void AS $$
BEGIN
    DELETE FROM club_posts WHERE expiry_date < NOW();
END;
$$ LANGUAGE plpgsql;

-- 10. Create storage bucket for post images (run this separately if needed)
INSERT INTO storage.buckets (id, name, public)
VALUES ('club-media', 'club-media', true)
ON CONFLICT (id) DO NOTHING;

-- 11. Storage policies for club-media bucket
CREATE POLICY "Anyone can view club media"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'club-media');

-- Allow any authenticated user to upload attachments to club-media
CREATE POLICY "Authenticated can upload club media"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'club-media'
    );

-- 12. Enable Realtime for posts (optional, for live updates)
-- ALTER PUBLICATION supabase_realtime ADD TABLE club_posts;
-- ALTER PUBLICATION supabase_realtime ADD TABLE club_post_kudos;
-- ALTER PUBLICATION supabase_realtime ADD TABLE club_post_comments;

-- Done! Your Posts feature database is ready.
