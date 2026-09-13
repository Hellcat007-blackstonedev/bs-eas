CREATE TABLE IF NOT EXISTS `bs_eas_alerts` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `type` VARCHAR(64) NOT NULL,
  `original_title` VARCHAR(120) DEFAULT NULL,
  `title` VARCHAR(120) NOT NULL,
  `headline` VARCHAR(255) NOT NULL,
  `message` TEXT NOT NULL,
  `issuer` VARCHAR(120) DEFAULT NULL,
  `issuer_id` VARCHAR(64) DEFAULT NULL,
  `sender` VARCHAR(120) DEFAULT NULL,
  `created_at` BIGINT NOT NULL,
  `updated_at` BIGINT DEFAULT NULL,
  `cleared_at` BIGINT DEFAULT NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT 'active',
  `level` VARCHAR(32) NOT NULL DEFAULT 'advice',
  `play_tone` TINYINT(1) NOT NULL DEFAULT 0,
  `zones` LONGTEXT DEFAULT NULL,
  `details` LONGTEXT DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bs_eas_revisions` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `alert_id` INT NOT NULL,
  `event_type` VARCHAR(32) NOT NULL,
  `title` VARCHAR(120) DEFAULT NULL,
  `headline` VARCHAR(255) DEFAULT NULL,
  `message` TEXT DEFAULT NULL,
  `issuer` VARCHAR(120) DEFAULT NULL,
  `issuer_id` VARCHAR(64) DEFAULT NULL,
  `level` VARCHAR(32) DEFAULT NULL,
  `zones` LONGTEXT DEFAULT NULL,
  `created_at` BIGINT NOT NULL,
  `sender` VARCHAR(120) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_bs_eas_revisions_alert` (`alert_id`),
  CONSTRAINT `fk_bs_eas_revisions_alert`
    FOREIGN KEY (`alert_id`) REFERENCES `bs_eas_alerts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bs_eas_recipients` (
  `alert_id` INT NOT NULL,
  `player_key` VARCHAR(100) NOT NULL,
  `last_revision` INT NOT NULL DEFAULT 1,
  PRIMARY KEY (`alert_id`, `player_key`),
  CONSTRAINT `fk_bs_eas_recipients_alert`
    FOREIGN KEY (`alert_id`) REFERENCES `bs_eas_alerts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
