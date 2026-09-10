-- ドパガキ指数(dopagaki_score)の採点理由。AI講評と同時に生成し、
-- 「AIによる講評」カードで点数の根拠として表示する。
-- 既存行には理由が無いため null 許容。
alter table ai_reviews
  add column score_reason text;
