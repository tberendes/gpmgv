--
-- PostgreSQL database dump
--

SET client_encoding = 'SQL_ASCII';
SET check_function_bodies = false;

SET SESSION AUTHORIZATION 'postgres';

--
-- TOC entry 4 (OID 2200)
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

SET search_path = public, pg_catalog;

--
-- TOC entry 5 (OID 17143)
-- Name: ct_temp; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE ct_temp (
    orbit integer,
    radar_name character varying,
    radar_id character varying,
    overpass_time timestamp with time zone,
    proximity double precision
);


--
-- TOC entry 6 (OID 17143)
-- Name: ct_temp; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE ct_temp FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE ct_temp TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 7 (OID 17341)
-- Name: heldmosaic; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE heldmosaic (
    nominal timestamp with time zone,
    filename character varying
);


--
-- TOC entry 8 (OID 17341)
-- Name: heldmosaic; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE heldmosaic FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE heldmosaic TO gvoper;
GRANT SELECT ON TABLE heldmosaic TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 9 (OID 20463)
-- Name: lineage; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE lineage (
    relationship character(1) NOT NULL,
    description character varying(6) NOT NULL
);


--
-- TOC entry 10 (OID 20463)
-- Name: lineage; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE lineage FROM PUBLIC;
GRANT SELECT ON TABLE lineage TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 11 (OID 20473)
-- Name: instrument; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE instrument (
    instrument_id character varying(15) NOT NULL,
    instrument_type character varying(31),
    instrument_name character varying(31),
    "owner" character varying(15),
    parent_child character(1) DEFAULT 'N'::bpchar NOT NULL,
    produces_data character(1) DEFAULT 'Y'::bpchar NOT NULL,
    fixed_or_moving character(1) DEFAULT 'F'::bpchar NOT NULL,
    coverage_type character varying(15),
    replaced_by_id character varying(15)
);


--
-- TOC entry 12 (OID 20473)
-- Name: instrument; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE instrument FROM PUBLIC;
GRANT SELECT ON TABLE instrument TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 13 (OID 20501)
-- Name: instrument_hierarchy; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE instrument_hierarchy (
    parent_instrument_id character varying(15) NOT NULL,
    child_instrument_id character varying(15) NOT NULL
);


--
-- TOC entry 14 (OID 20501)
-- Name: instrument_hierarchy; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE instrument_hierarchy FROM PUBLIC;
GRANT SELECT ON TABLE instrument_hierarchy TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 15 (OID 22962)
-- Name: coincident_mosaic; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE coincident_mosaic (
    orbit integer NOT NULL,
    filename character varying(31) NOT NULL
);


--
-- TOC entry 16 (OID 22962)
-- Name: coincident_mosaic; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE coincident_mosaic FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE coincident_mosaic TO gvoper;
GRANT SELECT ON TABLE coincident_mosaic TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 17 (OID 49354)
-- Name: overpass_event; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE overpass_event (
    event_num serial NOT NULL,
    sat_id character varying(15),
    orbit integer NOT NULL,
    radar_id character varying(15),
    overpass_time timestamp with time zone NOT NULL,
    nearest_distance integer NOT NULL
);


--
-- TOC entry 18 (OID 49354)
-- Name: overpass_event; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE overpass_event FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE overpass_event TO gvoper;
GRANT SELECT ON TABLE overpass_event TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 33 (OID 49354)
-- Name: overpass_event_event_num_seq; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE overpass_event_event_num_seq FROM PUBLIC;
GRANT SELECT ON TABLE overpass_event_event_num_seq TO PUBLIC;
GRANT UPDATE ON TABLE overpass_event_event_num_seq TO gvoper;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 19 (OID 52681)
-- Name: ctstatus; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE ctstatus (
    first_attempt date DEFAULT ('now'::text)::date,
    datestamp character(6) NOT NULL,
    ntries integer DEFAULT 0,
    status character(1) DEFAULT 'U'::bpchar
);


--
-- TOC entry 20 (OID 52681)
-- Name: ctstatus; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE ctstatus FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE ctstatus TO gvoper;
GRANT SELECT ON TABLE ctstatus TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 21 (OID 61432)
-- Name: orbit_subset_product; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE orbit_subset_product (
    sat_id character varying(15) NOT NULL,
    orbit integer NOT NULL,
    product_type character(4) NOT NULL,
    filedate date,
    filename character varying(40)
);


--
-- TOC entry 22 (OID 61432)
-- Name: orbit_subset_product; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE orbit_subset_product FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE orbit_subset_product TO gvoper;
GRANT SELECT ON TABLE orbit_subset_product TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 23 (OID 75890)
-- Name: gvradartemp; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE gvradartemp (
    product character varying(15) NOT NULL,
    radar_id character varying(15) NOT NULL,
    nominal timestamp with time zone NOT NULL,
    filepath character varying(63) NOT NULL,
    filename character varying(63) NOT NULL
);


--
-- TOC entry 24 (OID 75890)
-- Name: gvradartemp; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE gvradartemp FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE gvradartemp TO gvoper;
GRANT SELECT ON TABLE gvradartemp TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 25 (OID 87744)
-- Name: collatecols; Type: VIEW; Schema: public; Owner: morris
--

CREATE VIEW collatecols AS
    SELECT overpass_event.orbit, overpass_event.radar_id, date_trunc('hour'::text, overpass_event.overpass_time) AS nominal FROM overpass_event;


--
-- TOC entry 26 (OID 87744)
-- Name: collatecols; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE collatecols FROM PUBLIC;
GRANT SELECT ON TABLE collatecols TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 27 (OID 90151)
-- Name: gvradar; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE gvradar (
    product character varying(15) NOT NULL,
    radar_id character varying(15) NOT NULL,
    nominal timestamp with time zone NOT NULL,
    filepath character varying(63) NOT NULL,
    filename character varying(63) NOT NULL
);


--
-- TOC entry 28 (OID 90151)
-- Name: gvradar; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE gvradar FROM PUBLIC;
GRANT INSERT,SELECT ON TABLE gvradar TO gvoper;
GRANT SELECT ON TABLE gvradar TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 29 (OID 130372)
-- Name: collatedproducts; Type: VIEW; Schema: public; Owner: morris
--

CREATE VIEW collatedproducts AS
    SELECT a.orbit, a.radar_id, a.nominal, b.filename AS file2a54, c.filename AS file2a55, d.filename AS file1c21, e.filename AS file2a23, f.filename AS file2a25 FROM (((((collatecols a LEFT JOIN gvradar b USING (nominal, radar_id)) LEFT JOIN gvradar c USING (nominal, radar_id)) LEFT JOIN orbit_subset_product d USING (orbit)) LEFT JOIN orbit_subset_product e USING (orbit)) LEFT JOIN orbit_subset_product f USING (orbit)) WHERE ((((((b.product)::text = '2A54'::text) AND ((c.product)::text = '2A55'::text)) AND (d.product_type = '1C21'::bpchar)) AND (e.product_type = '2A23'::bpchar)) AND (f.product_type = '2A25'::bpchar));


--
-- TOC entry 30 (OID 130372)
-- Name: collatedproducts; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE collatedproducts FROM PUBLIC;
GRANT SELECT ON TABLE collatedproducts TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 31 (OID 130376)
-- Name: collatedzproducts; Type: VIEW; Schema: public; Owner: morris
--

CREATE VIEW collatedzproducts AS
    SELECT a.orbit, a.radar_id, a.nominal, b.filename AS file2a55, c.filename AS file2a25 FROM ((collatecols a LEFT JOIN gvradar b USING (nominal, radar_id)) LEFT JOIN orbit_subset_product c USING (orbit)) WHERE (((b.product)::text = '2A55'::text) AND (c.product_type = '2A25'::bpchar));


--
-- TOC entry 32 (OID 130376)
-- Name: collatedzproducts; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE collatedzproducts FROM PUBLIC;
GRANT SELECT ON TABLE collatedzproducts TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 34 (OID 20465)
-- Name: lineage_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY lineage
    ADD CONSTRAINT lineage_pkey PRIMARY KEY (relationship);


--
-- TOC entry 35 (OID 20478)
-- Name: instrument_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY instrument
    ADD CONSTRAINT instrument_pkey PRIMARY KEY (instrument_id);


--
-- TOC entry 36 (OID 20503)
-- Name: instrument_hierarchy_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY instrument_hierarchy
    ADD CONSTRAINT instrument_hierarchy_pkey PRIMARY KEY (parent_instrument_id, child_instrument_id);


--
-- TOC entry 37 (OID 22964)
-- Name: coincident_mosaic_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY coincident_mosaic
    ADD CONSTRAINT coincident_mosaic_pkey PRIMARY KEY (orbit, filename);


--
-- TOC entry 38 (OID 49357)
-- Name: overpass_event_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY overpass_event
    ADD CONSTRAINT overpass_event_pkey PRIMARY KEY (event_num);


--
-- TOC entry 39 (OID 49359)
-- Name: overpass_event_sat_id_key; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY overpass_event
    ADD CONSTRAINT overpass_event_sat_id_key UNIQUE (sat_id, radar_id, orbit);


--
-- TOC entry 40 (OID 52686)
-- Name: ctstatus_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY ctstatus
    ADD CONSTRAINT ctstatus_pkey PRIMARY KEY (datestamp);


--
-- TOC entry 41 (OID 61434)
-- Name: orbit_subset_product_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY orbit_subset_product
    ADD CONSTRAINT orbit_subset_product_pkey PRIMARY KEY (sat_id, orbit, product_type);


--
-- TOC entry 42 (OID 90153)
-- Name: gvradar_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY gvradar
    ADD CONSTRAINT gvradar_pkey PRIMARY KEY (filename);


--
-- TOC entry 43 (OID 20480)
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY instrument
    ADD CONSTRAINT "$1" FOREIGN KEY (parent_child) REFERENCES lineage(relationship);


--
-- TOC entry 44 (OID 20505)
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY instrument_hierarchy
    ADD CONSTRAINT "$1" FOREIGN KEY (parent_instrument_id) REFERENCES instrument(instrument_id);


--
-- TOC entry 45 (OID 20509)
-- Name: $2; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY instrument_hierarchy
    ADD CONSTRAINT "$2" FOREIGN KEY (child_instrument_id) REFERENCES instrument(instrument_id);


--
-- TOC entry 46 (OID 49361)
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY overpass_event
    ADD CONSTRAINT "$1" FOREIGN KEY (sat_id) REFERENCES instrument(instrument_id);


--
-- TOC entry 47 (OID 49365)
-- Name: $2; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY overpass_event
    ADD CONSTRAINT "$2" FOREIGN KEY (radar_id) REFERENCES instrument(instrument_id);


--
-- TOC entry 48 (OID 75892)
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY gvradartemp
    ADD CONSTRAINT "$1" FOREIGN KEY (radar_id) REFERENCES instrument(instrument_id);


--
-- TOC entry 49 (OID 130366)
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY gvradar
    ADD CONSTRAINT "$1" FOREIGN KEY (radar_id) REFERENCES instrument(instrument_id);


SET SESSION AUTHORIZATION 'postgres';

--
-- TOC entry 3 (OID 2200)
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'Standard public schema';


