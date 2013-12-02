-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Wed Aug 22 15:37:21 2012
-- 
--
-- Table: cryptokeys
--
DROP TABLE "cryptokeys" CASCADE;
CREATE TABLE "cryptokeys" (
  "id" serial NOT NULL,
  "domain_id" integer,
  "flags" integer NOT NULL,
  "active" boolean,
  "content" text,
  PRIMARY KEY ("id")
);
CREATE INDEX "cryptokeys_idx_domain_id" on "cryptokeys" ("domain_id");

--
-- Table: domainmetadata
--
DROP TABLE "domainmetadata" CASCADE;
CREATE TABLE "domainmetadata" (
  "id" serial NOT NULL,
  "domain_id" integer,
  "kind" character varying(16),
  "content" text,
  PRIMARY KEY ("id")
);
CREATE INDEX "domainmetadata_idx_domain_id" on "domainmetadata" ("domain_id");

--
-- Table: domains
--
DROP TABLE "domains" CASCADE;
CREATE TABLE "domains" (
  "id" serial NOT NULL,
  "name" character varying(255) NOT NULL,
  "master" character varying(20) DEFAULT null,
  "last_check" integer,
  "type" character varying(6) NOT NULL,
  "notified_serial" integer,
  "account" character varying(40) DEFAULT null,
  PRIMARY KEY ("id"),
  CONSTRAINT "name_index" UNIQUE ("name")
);

--
-- Table: records
--
DROP TABLE "records" CASCADE;
CREATE TABLE "records" (
  "id" serial NOT NULL,
  "domain_id" integer,
  "name" character varying(255) DEFAULT null,
  "type" character varying(10) DEFAULT null,
  "content" character varying(255) DEFAULT null,
  "ttl" integer,
  "prio" integer,
  "change_date" integer,
  "ordername" character varying(255),
  "auth" boolean,
  PRIMARY KEY ("id")
);
CREATE INDEX "records_idx_domain_id" on "records" ("domain_id");

--
-- Table: supermasters
--
DROP TABLE "supermasters" CASCADE;
CREATE TABLE "supermasters" (
  "ip" character varying(25) NOT NULL,
  "nameserver" character varying(255) NOT NULL,
  "account" character varying(40) DEFAULT null
);

--
-- Table: tsigkeys
--
DROP TABLE "tsigkeys" CASCADE;
CREATE TABLE "tsigkeys" (
  "id" serial NOT NULL,
  "name" character varying(255),
  "algorithm" character varying(255),
  "secret" character varying(255),
  PRIMARY KEY ("id"),
  CONSTRAINT "namealgoindex" UNIQUE ("name", "algorithm")
);

--
-- Foreign Key Definitions
--

ALTER TABLE "cryptokeys" ADD FOREIGN KEY ("domain_id")
  REFERENCES "domains" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "domainmetadata" ADD FOREIGN KEY ("domain_id")
  REFERENCES "domains" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "records" ADD FOREIGN KEY ("domain_id")
  REFERENCES "domains" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

