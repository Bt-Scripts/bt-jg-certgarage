-- cert-system database migration
-- Run once; safe to re-run (uses IF NOT EXISTS)

CREATE TABLE IF NOT EXISTS `player_certs` (
    `id`          INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `citizenid`   VARCHAR(50)     NOT NULL,
    `cert_name`   VARCHAR(100)    NOT NULL,
    `given_by`    VARCHAR(50)     NOT NULL,
    `given_at`    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_player_cert` (`citizenid`, `cert_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
