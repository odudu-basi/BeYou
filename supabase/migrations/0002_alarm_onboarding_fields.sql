-- New alarm-onboarding answers saved to user_profiles.
-- Safe to re-run: each column is added only if it doesn't already exist.

ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS morning_person        text;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS referred_from         text;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS biggest_obstacle      text;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS usual_wake_time       text;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS ideal_wake_time       text;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS time_to_feel_awake    text;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS feel_after_waking     text;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS trust_first_alarm     text;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS turn_off_alarm        text;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS negotiate_stay_in_bed text;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS alarm_thought         text;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS clear_brain_fog       text;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS alarm_count           text;
