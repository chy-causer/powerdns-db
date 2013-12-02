-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Wed Aug 22 15:37:21 2012
-- 

BEGIN TRANSACTION;

--
-- Table: cryptokeys
--
-- DROP TABLE cryptokeys;

CREATE TABLE cryptokeys (
  id INTEGER PRIMARY KEY NOT NULL,
  domain_id integer,
  flags integer NOT NULL,
  active boolean,
  content text,
  FOREIGN KEY(domain_id) REFERENCES domains(id)
);

CREATE INDEX cryptokeys_idx_domain_id ON cryptokeys (domain_id);

--
-- Table: domainmetadata
--
-- DROP TABLE domainmetadata;

CREATE TABLE domainmetadata (
  id INTEGER PRIMARY KEY NOT NULL,
  domain_id integer,
  kind varchar(16),
  content text,
  FOREIGN KEY(domain_id) REFERENCES domains(id)
);

CREATE INDEX domainmetadata_idx_domain_id ON domainmetadata (domain_id);

--
-- Table: domains
--
-- DROP TABLE domains;

CREATE TABLE domains (
  id INTEGER PRIMARY KEY NOT NULL,
  name varchar(255) NOT NULL,
  master varchar(20) DEFAULT null,
  last_check integer,
  type varchar(6) NOT NULL,
  notified_serial integer,
  account varchar(40) DEFAULT null
);

CREATE UNIQUE INDEX name_index ON domains (name);

--
-- Table: records
--
-- DROP TABLE records;

CREATE TABLE records (
  id INTEGER PRIMARY KEY NOT NULL,
  domain_id integer,
  name varchar(255) DEFAULT null,
  type varchar(10) DEFAULT null,
  content varchar(255) DEFAULT null,
  ttl integer,
  prio integer,
  change_date integer,
  ordername varchar(255),
  auth boolean,
  FOREIGN KEY(domain_id) REFERENCES domains(id)
);

CREATE INDEX records_idx_domain_id ON records (domain_id);

--
-- Table: supermasters
--
-- DROP TABLE supermasters;

CREATE TABLE supermasters (
  ip varchar(25) NOT NULL,
  nameserver varchar(255) NOT NULL,
  account varchar(40) DEFAULT null
);

--
-- Table: tsigkeys
--
-- DROP TABLE tsigkeys;

CREATE TABLE tsigkeys (
  id INTEGER PRIMARY KEY NOT NULL,
  name varchar(255),
  algorithm varchar(255),
  secret varchar(255)
);

CREATE UNIQUE INDEX namealgoindex ON tsigkeys (name, algorithm);

COMMIT;
