-- ai_reviews.comment is a single text column, but the app's AiCommentary model
-- also has a bulleted advice list (adviceList: List<String>). Add a column for
-- it instead of collapsing it into comment.
alter table ai_reviews
  add column advice jsonb not null default '[]'::jsonb;
