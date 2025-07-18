CREATE TABLE IF NOT EXISTS `vehicle_trunks` (
  `plate` varchar(12) NOT NULL,
  `items` longtext DEFAULT NULL,
  `dirty_money` int(11) DEFAULT 0,
  `clean_money` int(11) DEFAULT 0,
  PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;