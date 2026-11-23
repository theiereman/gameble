-- Calibration of the service ladders. Run on production:
--   psql "$DATABASE_URL" -f calibration.sql
-- Part 1: one row per active member. Part 2: percentiles per counter.

-- Only temporary views are created, and the transaction is rolled back.
BEGIN;

CREATE TEMP VIEW members AS
SELECT id, token, persona_name, role, created_at
  FROM accounts_players
 WHERE banned_at IS NULL AND deleted_at IS NULL AND bot_of_id IS NULL;

CREATE TEMP VIEW service_counters AS
SELECT m.persona_name,
       m.token,
       m.role,
       m.created_at::date AS joined_on,
       -- common floor
       (SELECT count(*) FROM game_daily_bonus_claims c WHERE c.player_id = m.id) AS days_of_service,
       (SELECT count(DISTINCT p.opened_at::date) FROM game_packs p WHERE p.player_id = m.id AND p.opened_at IS NOT NULL) AS active_days,
       -- Archives
       (SELECT count(*) FROM game_packs p WHERE p.player_id = m.id AND p.opened_at IS NOT NULL) AS capsules_opened,
       (SELECT count(*) FROM game_set_tiers t WHERE t.player_id = m.id AND t.tier = 'complete') AS sets_completed,
       (SELECT count(*) FROM game_set_tiers t WHERE t.player_id = m.id AND t.tier IN ('master', 'gold')) AS master_or_gold_tiers,
       (SELECT count(*) FROM game_first_discoveries f WHERE f.player_id = m.id) AS pioneer_discoveries,
       -- Bourse
       (SELECT count(*) FROM game_market_listings l WHERE l.seller_id = m.id AND l.status = 'sold') AS market_sales,
       (SELECT count(*) FROM game_market_listings l WHERE l.leader_id = m.id AND l.status = 'sold') AS market_purchases,
       (SELECT coalesce(sum(d.quantity), 0) FROM game_market_archive_deposits d WHERE d.player_id = m.id) AS cards_entrusted,
       -- Relations entre membres
       (SELECT count(*) FROM game_trades tr WHERE m.id IN (tr.low_player_id, tr.high_player_id) AND tr.status = 'accepted') AS trades_accepted,
       (SELECT count(DISTINCT CASE WHEN tr.low_player_id = m.id THEN tr.high_player_id ELSE tr.low_player_id END)
          FROM game_trades tr WHERE m.id IN (tr.low_player_id, tr.high_player_id) AND tr.status = 'accepted') AS trade_partners,
       -- Contentieux
       (SELECT count(*) FROM game_duel_seats s JOIN game_duels d ON d.id = s.duel_id
         WHERE s.player_id = m.id AND d.state = 'finished' AND NOT d.practice) AS duels_finished,
       (SELECT count(*) FROM game_duel_seats s JOIN game_duels d ON d.id = s.duel_id
         WHERE s.player_id = m.id AND d.state = 'finished' AND NOT d.practice AND d.result = s.role) AS duels_won,
       (SELECT count(DISTINCT o.player_id) FROM game_duel_seats s JOIN game_duels d ON d.id = s.duel_id
          JOIN game_duel_seats o ON o.duel_id = d.id AND o.id <> s.id
         WHERE s.player_id = m.id AND d.state = 'finished' AND NOT d.practice) AS duel_opponents
  FROM members m;

-- Part 1: counters per member (members with at least one day of service)
SELECT * FROM service_counters WHERE days_of_service > 0 ORDER BY days_of_service DESC, capsules_opened DESC;

-- Part 2: percentiles among members with at least one day of service
SELECT counter,
       count(*) FILTER (WHERE value > 0) AS members_above_zero,
       percentile_disc(0.50) WITHIN GROUP (ORDER BY value) AS p50,
       percentile_disc(0.75) WITHIN GROUP (ORDER BY value) AS p75,
       percentile_disc(0.90) WITHIN GROUP (ORDER BY value) AS p90,
       percentile_disc(0.97) WITHIN GROUP (ORDER BY value) AS p97,
       percentile_disc(0.99) WITHIN GROUP (ORDER BY value) AS p99,
       max(value) AS max
  FROM service_counters,
       LATERAL (VALUES ('days_of_service', days_of_service), ('active_days', active_days),
                       ('capsules_opened', capsules_opened), ('sets_completed', sets_completed),
                       ('master_or_gold_tiers', master_or_gold_tiers), ('pioneer_discoveries', pioneer_discoveries),
                       ('market_sales', market_sales), ('market_purchases', market_purchases),
                       ('cards_entrusted', cards_entrusted), ('trades_accepted', trades_accepted),
                       ('trade_partners', trade_partners), ('duels_finished', duels_finished),
                       ('duels_won', duels_won), ('duel_opponents', duel_opponents)) AS v(counter, value)
 WHERE days_of_service > 0
 GROUP BY counter
 ORDER BY counter;

ROLLBACK;
