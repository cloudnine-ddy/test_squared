-- TestSquared Enhancement Migration
-- Features: Progress Tracking, Bookmarks, Notes, AI Explanations, Analytics
-- Created: 2025-01-01

-- ============================================================================
-- 1. USER QUESTION ATTEMPTS - Track all student attempts
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_question_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  question_id UUID REFERENCES questions(id) ON DELETE CASCADE NOT NULL,
  answer_text TEXT,
  selected_option TEXT, -- For MCQ: 'A', 'B', 'C', 'D'
  score INTEGER CHECK (score >= 0 AND score <= 100),
  is_correct BOOLEAN,
  time_spent_seconds INTEGER DEFAULT 0,
  hints_used INTEGER DEFAULT 0,
  attempted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_attempts_user ON user_question_attempts(user_id);
CREATE INDEX idx_attempts_question ON user_question_attempts(question_id);
CREATE INDEX idx_attempts_date ON user_question_attempts(attempted_at DESC);
CREATE INDEX idx_attempts_user_date ON user_question_attempts(user_id, attempted_at DESC);

-- ============================================================================
-- 2. USER BOOKMARKS - Save questions for later
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_bookmarks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  question_id UUID REFERENCES questions(id) ON DELETE CASCADE NOT NULL,
  folder_name TEXT DEFAULT 'My Bookmarks' NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  CONSTRAINT unique_bookmark UNIQUE(user_id, question_id)
);

CREATE INDEX idx_bookmarks_user ON user_bookmarks(user_id);
CREATE INDEX idx_bookmarks_folder ON user_bookmarks(user_id, folder_name);
CREATE INDEX idx_bookmarks_created ON user_bookmarks(created_at DESC);

-- ============================================================================
-- 3. QUESTION NOTES - Personal notes on questions
-- ============================================================================
CREATE TABLE IF NOT EXISTS question_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  question_id UUID REFERENCES questions(id) ON DELETE CASCADE NOT NULL,
  note_text TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  CONSTRAINT unique_note UNIQUE(user_id, question_id)
);

CREATE INDEX idx_notes_user ON question_notes(user_id);
CREATE INDEX idx_notes_question ON question_notes(question_id);

-- ============================================================================
-- 4. AI EXPLANATIONS - Cache AI-generated explanations
-- ============================================================================
CREATE TABLE IF NOT EXISTS ai_explanations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id UUID REFERENCES questions(id) ON DELETE CASCADE NOT NULL,
  explanation_type TEXT NOT NULL CHECK (explanation_type IN ('full', 'hint_1', 'hint_2', 'hint_3')),
  content TEXT NOT NULL,
  key_points JSONB,
  common_mistakes JSONB,
  related_topics JSONB,
  generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  CONSTRAINT unique_explanation UNIQUE(question_id, explanation_type)
);

CREATE INDEX idx_explanations_question ON ai_explanations(question_id);
CREATE INDEX idx_explanations_type ON ai_explanations(question_id, explanation_type);

-- ============================================================================
-- 5. ADMIN ACTIVITY LOG - Audit trail
-- ============================================================================
CREATE TABLE IF NOT EXISTS admin_activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action_type TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  details JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_activity_admin ON admin_activity_log(admin_id);
CREATE INDEX idx_activity_date ON admin_activity_log(created_at DESC);
CREATE INDEX idx_activity_type ON admin_activity_log(action_type);

-- ============================================================================
-- 6. USER TOPIC STATS - Materialized view for performance
-- ============================================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS user_topic_stats AS
SELECT 
  uqa.user_id,
  qt.topic_id::UUID as topic_id,
  COUNT(*) as total_attempts,
  SUM(CASE WHEN uqa.is_correct THEN 1 ELSE 0 END) as correct_count,
  ROUND(AVG(uqa.score)::numeric, 2) as avg_score,
  MAX(uqa.attempted_at) as last_practiced,
  COUNT(DISTINCT uqa.question_id) as unique_questions_attempted
FROM user_question_attempts uqa
JOIN questions q ON uqa.question_id = q.id
CROSS JOIN UNNEST(q.topic_ids) AS qt(topic_id)
WHERE uqa.score IS NOT NULL
GROUP BY uqa.user_id, qt.topic_id;

CREATE UNIQUE INDEX idx_user_topic_stats_unique ON user_topic_stats(user_id, topic_id);
CREATE INDEX idx_user_topic_stats_user ON user_topic_stats(user_id);

-- Function to refresh materialized view
CREATE OR REPLACE FUNCTION refresh_user_topic_stats()
RETURNS void 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY user_topic_stats;
END;
$$;

-- ============================================================================
-- 7. FULL-TEXT SEARCH - Add search capabilities to questions
-- ============================================================================
-- Add tsvector column for full-text search
ALTER TABLE questions ADD COLUMN IF NOT EXISTS search_vector tsvector;

-- Create index for full-text search
CREATE INDEX IF NOT EXISTS idx_questions_search ON questions USING GIN(search_vector);

-- Function to update search vector
CREATE OR REPLACE FUNCTION update_question_search_vector()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.search_vector := 
    setweight(to_tsvector('english', COALESCE(NEW.content, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(NEW.official_answer, '')), 'B');
  RETURN NEW;
END;
$$;

-- Trigger to automatically update search vector
DROP TRIGGER IF EXISTS trigger_update_question_search ON questions;
CREATE TRIGGER trigger_update_question_search
  BEFORE INSERT OR UPDATE OF content, official_answer
  ON questions
  FOR EACH ROW
  EXECUTE FUNCTION update_question_search_vector();

-- Update existing questions
UPDATE questions SET search_vector = 
  setweight(to_tsvector('english', COALESCE(content, '')), 'A') ||
  setweight(to_tsvector('english', COALESCE(official_answer, '')), 'B')
WHERE search_vector IS NULL;

-- ============================================================================
-- ROW-LEVEL SECURITY POLICIES
-- ============================================================================

-- user_question_attempts
ALTER TABLE user_question_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own attempts" ON user_question_attempts;
CREATE POLICY "Users can view own attempts"
  ON user_question_attempts FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own attempts" ON user_question_attempts;
CREATE POLICY "Users can insert own attempts"
  ON user_question_attempts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all attempts" ON user_question_attempts;
CREATE POLICY "Admins can view all attempts"
  ON user_question_attempts FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- user_bookmarks
ALTER TABLE user_bookmarks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own bookmarks" ON user_bookmarks;
CREATE POLICY "Users can manage own bookmarks"
  ON user_bookmarks FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- question_notes
ALTER TABLE question_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own notes" ON question_notes;
CREATE POLICY "Users can manage own notes"
  ON question_notes FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ai_explanations
ALTER TABLE ai_explanations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read explanations" ON ai_explanations;
CREATE POLICY "Anyone can read explanations"
  ON ai_explanations FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "System can manage explanations" ON ai_explanations;
CREATE POLICY "System can manage explanations"
  ON ai_explanations FOR ALL
  USING (true)
  WITH CHECK (true);

-- admin_activity_log
ALTER TABLE admin_activity_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view activity log" ON admin_activity_log;
CREATE POLICY "Admins can view activity log"
  ON admin_activity_log FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can insert activity log" ON admin_activity_log;
CREATE POLICY "Admins can insert activity log"
  ON admin_activity_log FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to log admin activity
CREATE OR REPLACE FUNCTION log_admin_activity(
  p_action_type TEXT,
  p_entity_type TEXT DEFAULT NULL,
  p_entity_id UUID DEFAULT NULL,
  p_details JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_log_id UUID;
BEGIN
  INSERT INTO admin_activity_log (admin_id, action_type, entity_type, entity_id, details)
  VALUES (auth.uid(), p_action_type, p_entity_type, p_entity_id, p_details)
  RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$;

-- Function to get user overall stats
CREATE OR REPLACE FUNCTION get_user_overall_stats(p_user_id UUID)
RETURNS TABLE (
  total_attempts BIGINT,
  total_questions_attempted BIGINT,
  total_correct BIGINT,
  overall_accuracy NUMERIC,
  avg_score NUMERIC,
  total_time_spent BIGINT,
  current_streak INTEGER,
  longest_streak INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::BIGINT as total_attempts,
    COUNT(DISTINCT question_id)::BIGINT as total_questions_attempted,
    SUM(CASE WHEN is_correct THEN 1 ELSE 0 END)::BIGINT as total_correct,
    ROUND(
      (SUM(CASE WHEN is_correct THEN 1 ELSE 0 END)::NUMERIC / 
       NULLIF(COUNT(*), 0) * 100)::NUMERIC, 
      2
    ) as overall_accuracy,
    ROUND(AVG(score)::NUMERIC, 2) as avg_score,
    SUM(time_spent_seconds)::BIGINT as total_time_spent,
    0 as current_streak, -- TODO: Implement streak calculation
    0 as longest_streak  -- TODO: Implement streak calculation
  FROM user_question_attempts
  WHERE user_id = p_user_id;
END;
$$;

-- Function to get weak areas for a user
CREATE OR REPLACE FUNCTION get_user_weak_areas(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
  topic_id UUID,
  topic_name TEXT,
  accuracy NUMERIC,
  total_attempts BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    uts.topic_id,
    t.name as topic_name,
    ROUND((uts.correct_count::NUMERIC / NULLIF(uts.total_attempts, 0) * 100)::NUMERIC, 2) as accuracy,
    uts.total_attempts
  FROM user_topic_stats uts
  JOIN topics t ON uts.topic_id = t.id
  WHERE uts.user_id = p_user_id
    AND uts.total_attempts >= 3 -- Only topics with at least 3 attempts
  ORDER BY accuracy ASC, uts.total_attempts DESC
  LIMIT p_limit;
END;
$$;

-- ============================================================================
-- ANALYTICS FUNCTIONS FOR ADMIN
-- ============================================================================

-- Function to get overall platform analytics
CREATE OR REPLACE FUNCTION get_platform_analytics()
RETURNS TABLE (
  total_users BIGINT,
  active_users_7d BIGINT,
  active_users_30d BIGINT,
  total_questions BIGINT,
  total_attempts BIGINT,
  avg_platform_score NUMERIC,
  total_bookmarks BIGINT,
  total_notes BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (SELECT COUNT(*) FROM profiles WHERE role = 'student')::BIGINT as total_users,
    (SELECT COUNT(DISTINCT user_id) FROM user_question_attempts 
     WHERE attempted_at >= NOW() - INTERVAL '7 days')::BIGINT as active_users_7d,
    (SELECT COUNT(DISTINCT user_id) FROM user_question_attempts 
     WHERE attempted_at >= NOW() - INTERVAL '30 days')::BIGINT as active_users_30d,
    (SELECT COUNT(*) FROM questions)::BIGINT as total_questions,
    (SELECT COUNT(*) FROM user_question_attempts)::BIGINT as total_attempts,
    (SELECT ROUND(AVG(score)::NUMERIC, 2) FROM user_question_attempts 
     WHERE score IS NOT NULL) as avg_platform_score,
    (SELECT COUNT(*) FROM user_bookmarks)::BIGINT as total_bookmarks,
    (SELECT COUNT(*) FROM question_notes)::BIGINT as total_notes;
END;
$$;

-- Function to get topic popularity
CREATE OR REPLACE FUNCTION get_topic_popularity(p_limit INTEGER DEFAULT 10)
RETURNS TABLE (
  topic_id UUID,
  topic_name TEXT,
  attempt_count BIGINT,
  unique_users BIGINT,
  avg_score NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.id as topic_id,
    t.name as topic_name,
    COUNT(uqa.id)::BIGINT as attempt_count,
    COUNT(DISTINCT uqa.user_id)::BIGINT as unique_users,
    ROUND(AVG(uqa.score)::NUMERIC, 2) as avg_score
  FROM topics t
  LEFT JOIN questions q ON t.id = ANY(q.topic_ids)
  LEFT JOIN user_question_attempts uqa ON q.id = uqa.question_id
  GROUP BY t.id, t.name
  ORDER BY attempt_count DESC
  LIMIT p_limit;
END;
$$;

-- ============================================================================
-- SCHEDULED JOBS (Run these periodically via cron or pg_cron)
-- ============================================================================

-- Refresh materialized view daily
-- SCHEDULE: 0 2 * * * (2 AM daily)
-- SELECT refresh_user_topic_stats();

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

-- Verify tables were created
DO $$
BEGIN
  RAISE NOTICE 'Migration completed successfully!';
  RAISE NOTICE 'Created tables:';
  RAISE NOTICE '  - user_question_attempts';
  RAISE NOTICE '  - user_bookmarks';
  RAISE NOTICE '  - question_notes';
  RAISE NOTICE '  - ai_explanations';
  RAISE NOTICE '  - admin_activity_log';
  RAISE NOTICE 'Created materialized view:';
  RAISE NOTICE '  - user_topic_stats';
  RAISE NOTICE 'Created functions:';
  RAISE NOTICE '  - refresh_user_topic_stats()';
  RAISE NOTICE '  - log_admin_activity()';
  RAISE NOTICE '  - get_user_overall_stats()';
  RAISE NOTICE '  - get_user_weak_areas()';
  RAISE NOTICE '  - get_platform_analytics()';
  RAISE NOTICE '  - get_topic_popularity()';
END $$;
