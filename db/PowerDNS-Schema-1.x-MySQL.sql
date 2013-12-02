-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Wed Aug 22 15:37:21 2012
-- 
SET foreign_key_checks=0;

DROP TABLE IF EXISTS `cryptokeys`;

--
-- Table: `cryptokeys`
--
CREATE TABLE `cryptokeys` (
  `id` integer NOT NULL auto_increment,
  `domain_id` integer,
  `flags` integer NOT NULL,
  `active` enum('0','1'),
  `content` text,
  INDEX `cryptokeys_idx_domain_id` (`domain_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `cryptokeys_fk_domain_id` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS `domainmetadata`;

--
-- Table: `domainmetadata`
--
CREATE TABLE `domainmetadata` (
  `id` integer NOT NULL auto_increment,
  `domain_id` integer,
  `kind` varchar(16),
  `content` text,
  INDEX `domainmetadata_idx_domain_id` (`domain_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `domainmetadata_fk_domain_id` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS `domains`;

--
-- Table: `domains`
--
CREATE TABLE `domains` (
  `id` integer NOT NULL auto_increment,
  `name` varchar(255) NOT NULL,
  `master` varchar(20) DEFAULT null,
  `last_check` integer,
  `type` varchar(6) NOT NULL,
  `notified_serial` integer,
  `account` varchar(40) DEFAULT null,
  PRIMARY KEY (`id`),
  UNIQUE `name_index` (`name`)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS `records`;

--
-- Table: `records`
--
CREATE TABLE `records` (
  `id` integer NOT NULL auto_increment,
  `domain_id` integer,
  `name` varchar(255) DEFAULT null,
  `type` varchar(10) DEFAULT null,
  `content` varchar(255) DEFAULT null,
  `ttl` integer,
  `prio` integer,
  `change_date` integer,
  `ordername` varchar(255),
  `auth` enum('0','1'),
  INDEX `records_idx_domain_id` (`domain_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `records_fk_domain_id` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS `supermasters`;

--
-- Table: `supermasters`
--
CREATE TABLE `supermasters` (
  `ip` varchar(25) NOT NULL,
  `nameserver` varchar(255) NOT NULL,
  `account` varchar(40) DEFAULT null
);

DROP TABLE IF EXISTS `tsigkeys`;

--
-- Table: `tsigkeys`
--
CREATE TABLE `tsigkeys` (
  `id` integer NOT NULL auto_increment,
  `name` varchar(255),
  `algorithm` varchar(255),
  `secret` varchar(255),
  PRIMARY KEY (`id`),
  UNIQUE `namealgoindex` (`name`, `algorithm`)
);

SET foreign_key_checks=1;

