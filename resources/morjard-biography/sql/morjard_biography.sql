-- morjard-biography SQL schema
CREATE TABLE IF NOT EXISTS `morjard_biography` (
  `id` int NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(64) NOT NULL UNIQUE,
  `firstname` varchar(64) DEFAULT NULL,
  `lastname` varchar(64) DEFAULT NULL,
  `total_minutes` int DEFAULT 0,
  `jobs` json DEFAULT JSON_OBJECT(),
  `job_history` json DEFAULT JSON_ARRAY(),
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Index for quick lookup
CREATE INDEX IF NOT EXISTS idx_morjard_citizenid ON morjard_biography (citizenid);
