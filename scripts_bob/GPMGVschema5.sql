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
-- TOC entry 88 (OID 49354)
-- Name: overpass_event_event_num_seq; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE overpass_event_event_num_seq FROM PUBLIC;
GRANT SELECT ON TABLE overpass_event_event_num_seq TO PUBLIC;
GRANT SELECT,UPDATE ON TABLE overpass_event_event_num_seq TO gvoper;


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
    filename character varying(40),
    subset character varying(15) NOT NULL
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
-- TOC entry 25 (OID 90151)
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
-- TOC entry 26 (OID 90151)
-- Name: gvradar; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE gvradar FROM PUBLIC;
GRANT INSERT,SELECT ON TABLE gvradar TO gvoper;
GRANT SELECT ON TABLE gvradar TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 27 (OID 130401)
-- Name: collatecols; Type: VIEW; Schema: public; Owner: morris
--

CREATE VIEW collatecols AS
    SELECT overpass_event.orbit, overpass_event.radar_id, overpass_event.overpass_time, date_trunc('hour'::text, overpass_event.overpass_time) AS nominal FROM overpass_event;


--
-- TOC entry 28 (OID 130401)
-- Name: collatecols; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE collatecols FROM PUBLIC;
GRANT SELECT ON TABLE collatecols TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 29 (OID 130404)
-- Name: collatedproducts; Type: VIEW; Schema: public; Owner: morris
--

CREATE VIEW collatedproducts AS
    SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, b.filename AS file2a54, c.filename AS file2a55, d.filename AS file1c21, e.filename AS file2a23, f.filename AS file2a25 FROM (((((collatecols a LEFT JOIN gvradar b ON ((((a.nominal = b.nominal) AND ((a.radar_id)::text = (b.radar_id)::text)) AND ((b.product)::text = '2A54'::text)))) LEFT JOIN gvradar c ON ((((a.nominal = c.nominal) AND ((a.radar_id)::text = (c.radar_id)::text)) AND ((c.product)::text = '2A55'::text)))) LEFT JOIN orbit_subset_product d ON (((a.orbit = d.orbit) AND (d.product_type = '1C21'::bpchar)))) LEFT JOIN orbit_subset_product e ON (((a.orbit = e.orbit) AND (e.product_type = '2A23'::bpchar)))) LEFT JOIN orbit_subset_product f ON (((a.orbit = f.orbit) AND (f.product_type = '2A25'::bpchar))));


--
-- TOC entry 30 (OID 130404)
-- Name: collatedproducts; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE collatedproducts FROM PUBLIC;
GRANT SELECT ON TABLE collatedproducts TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 31 (OID 130411)
-- Name: collatedmosaics; Type: VIEW; Schema: public; Owner: morris
--

CREATE VIEW collatedmosaics AS
    SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, min((b.filename)::text) AS "first", max((c.filename)::text) AS "second" FROM ((collatecols a NATURAL JOIN coincident_mosaic b) LEFT JOIN coincident_mosaic c ON (((b.orbit = c.orbit) AND ((b.filename)::text <> (c.filename)::text)))) GROUP BY a.orbit, overpass_time, nominal, radar_id;


--
-- TOC entry 32 (OID 130411)
-- Name: collatedmosaics; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE collatedmosaics FROM PUBLIC;
GRANT SELECT ON TABLE collatedmosaics TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 33 (OID 150319)
-- Name: fixed_instrument_location; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE fixed_instrument_location (
    instrument_id character varying(15) NOT NULL,
    install_date date NOT NULL,
    state_province character(2),
    country character(2),
    latitude real NOT NULL,
    longitude real NOT NULL,
    elevation smallint
);


--
-- TOC entry 34 (OID 150319)
-- Name: fixed_instrument_location; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE fixed_instrument_location FROM PUBLIC;
GRANT SELECT ON TABLE fixed_instrument_location TO gvoper;
GRANT SELECT ON TABLE fixed_instrument_location TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 35 (OID 154409)
-- Name: appstatus; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE appstatus (
    app_id character(15) NOT NULL,
    first_attempt date DEFAULT ('now'::text)::date,
    datestamp character(6) NOT NULL,
    ntries integer DEFAULT 0,
    status character(1) DEFAULT 'U'::bpchar
);


--
-- TOC entry 36 (OID 154409)
-- Name: appstatus; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE appstatus FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE appstatus TO gvoper;
GRANT SELECT ON TABLE appstatus TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 37 (OID 163762)
-- Name: metadata_parameter; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE metadata_parameter (
    metadata_id integer NOT NULL,
    data_type character varying(10) NOT NULL,
    parameter_definition character varying(63) NOT NULL
);


--
-- TOC entry 38 (OID 163762)
-- Name: metadata_parameter; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE metadata_parameter FROM PUBLIC;
GRANT SELECT ON TABLE metadata_parameter TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 39 (OID 167884)
-- Name: metadata_temp; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE metadata_temp (
    event_num integer NOT NULL,
    metadata_id integer NOT NULL,
    value double precision NOT NULL
);


--
-- TOC entry 40 (OID 167884)
-- Name: metadata_temp; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE metadata_temp FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE metadata_temp TO gvoper;
GRANT SELECT ON TABLE metadata_temp TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 41 (OID 180243)
-- Name: event_meta_numeric; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE event_meta_numeric (
    event_num integer NOT NULL,
    metadata_id integer NOT NULL,
    value double precision NOT NULL
);


--
-- TOC entry 42 (OID 180243)
-- Name: event_meta_numeric; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE event_meta_numeric FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE event_meta_numeric TO gvoper;
GRANT SELECT ON TABLE event_meta_numeric TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 43 (OID 283743)
-- Name: gvradarvolume; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE gvradarvolume (
    volume_id serial NOT NULL,
    filename character varying(63),
    start_time timestamp with time zone
);


--
-- TOC entry 44 (OID 283743)
-- Name: gvradarvolume; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE gvradarvolume FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE gvradarvolume TO gvoper;
GRANT SELECT ON TABLE gvradarvolume TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 89 (OID 283743)
-- Name: gvradarvolume_volume_id_seq; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE gvradarvolume_volume_id_seq FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE gvradarvolume_volume_id_seq TO gvoper;
GRANT SELECT ON TABLE gvradarvolume_volume_id_seq TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 45 (OID 283784)
-- Name: gvradvol_temp; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE gvradvol_temp (
    filename character varying(63),
    start_time timestamp with time zone
);


--
-- TOC entry 46 (OID 283784)
-- Name: gvradvol_temp; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE gvradvol_temp FROM PUBLIC;
GRANT INSERT,SELECT,DELETE ON TABLE gvradvol_temp TO gvoper;
GRANT SELECT ON TABLE gvradvol_temp TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 47 (OID 296549)
-- Name: event_meta_2a25_vw; Type: VIEW; Schema: public; Owner: morris
--

CREATE VIEW event_meta_2a25_vw AS
    SELECT a.event_num, a.radar_id, a.orbit, a.overpass_time, a.nearest_distance, (b.value / (56.25)::double precision) AS pct_overlap, ((c.value / b.value) * (100)::double precision) AS pct_overlap_bb_exists, ((d.value / b.value) * (100)::double precision) AS pct_overlap_rain_certain, e.value AS avg_bb_height FROM ((((overpass_event a LEFT JOIN event_meta_numeric b ON (((a.event_num = b.event_num) AND (b.metadata_id = 250999)))) LEFT JOIN event_meta_numeric c ON (((a.event_num = c.event_num) AND (c.metadata_id = 251004)))) LEFT JOIN event_meta_numeric d ON (((a.event_num = d.event_num) AND (d.metadata_id = 251005)))) LEFT JOIN event_meta_numeric e ON (((a.event_num = e.event_num) AND (e.metadata_id = 251003))));


--
-- TOC entry 48 (OID 296549)
-- Name: event_meta_2a25_vw; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE event_meta_2a25_vw FROM PUBLIC;
GRANT SELECT ON TABLE event_meta_2a25_vw TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 49 (OID 338325)
-- Name: collatedzproducts; Type: VIEW; Schema: public; Owner: morris
--

CREATE VIEW collatedzproducts AS
    SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, (((((a.radar_id)::text || '/'::text) || (b.filepath)::text) || '/'::text) || (b.filename)::text) AS file2a55, c.filename AS file2a25, d.filename AS file1c21 FROM (((collatecols a LEFT JOIN gvradar b ON ((((a.nominal = b.nominal) AND ((a.radar_id)::text = (b.radar_id)::text)) AND ((b.product)::text = '2A55'::text)))) LEFT JOIN orbit_subset_product c ON (((a.orbit = c.orbit) AND (c.product_type = '2A25'::bpchar)))) LEFT JOIN orbit_subset_product d ON (((a.orbit = d.orbit) AND (d.product_type = '1C21'::bpchar))));


--
-- TOC entry 50 (OID 338325)
-- Name: collatedzproducts; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE collatedzproducts FROM PUBLIC;
GRANT SELECT ON TABLE collatedzproducts TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 51 (OID 372886)
-- Name: event_meta_2a23_vw; Type: VIEW; Schema: public; Owner: morris
--

CREATE VIEW event_meta_2a23_vw AS
    SELECT a.event_num, a.radar_id, a.orbit, a.overpass_time, a.nearest_distance, (b.value / (56.25)::double precision) AS pct_overlap, ((c.value / b.value) * (100)::double precision) AS pct_overlap_strat, ((d.value / b.value) * (100)::double precision) AS pct_overlap_conv FROM (((overpass_event a LEFT JOIN event_meta_numeric b ON (((a.event_num = b.event_num) AND (b.metadata_id = 250999)))) LEFT JOIN event_meta_numeric c ON (((a.event_num = c.event_num) AND (c.metadata_id = 230001)))) LEFT JOIN event_meta_numeric d ON (((c.event_num = d.event_num) AND (d.metadata_id = 230002))));


--
-- TOC entry 52 (OID 372886)
-- Name: event_meta_2a23_vw; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE event_meta_2a23_vw FROM PUBLIC;
GRANT SELECT ON TABLE event_meta_2a23_vw TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 53 (OID 403882)
-- Name: productsubset; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE productsubset (
    sat_id character varying(15) NOT NULL,
    subset character varying(15) NOT NULL
);


--
-- TOC entry 54 (OID 403882)
-- Name: productsubset; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE productsubset FROM PUBLIC;
GRANT SELECT ON TABLE productsubset TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 55 (OID 403900)
-- Name: siteproductsubset; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE siteproductsubset (
    sat_id character varying(15) NOT NULL,
    subset character varying(15) NOT NULL,
    radar_id character varying(15) NOT NULL
);


--
-- TOC entry 56 (OID 403900)
-- Name: siteproductsubset; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE siteproductsubset FROM PUBLIC;
GRANT SELECT ON TABLE siteproductsubset TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 57 (OID 450008)
-- Name: collatecolswsub; Type: VIEW; Schema: public; Owner: morris
--

CREATE VIEW collatecolswsub AS
    SELECT a.orbit, a.radar_id, a.overpass_time, date_trunc('hour'::text, a.overpass_time) AS nominal, b.subset FROM overpass_event a, siteproductsubset b WHERE (((a.radar_id)::text = (b.radar_id)::text) AND ((a.sat_id)::text = (b.sat_id)::text));


--
-- TOC entry 58 (OID 450008)
-- Name: collatecolswsub; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE collatecolswsub FROM PUBLIC;
GRANT SELECT ON TABLE collatecolswsub TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 59 (OID 450016)
-- Name: collatedzproductswsub; Type: VIEW; Schema: public; Owner: morris
--

CREATE VIEW collatedzproductswsub AS
    SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, (((((a.radar_id)::text || '/'::text) || (b.filepath)::text) || '/'::text) || (b.filename)::text) AS file2a55, c.filename AS file2a25, d.filename AS file1c21 FROM (((collatecolswsub a LEFT JOIN gvradar b ON ((((a.nominal = b.nominal) AND ((a.radar_id)::text = (b.radar_id)::text)) AND ((b.product)::text = '2A55'::text)))) LEFT JOIN orbit_subset_product c ON ((((a.orbit = c.orbit) AND ((a.subset)::text = (c.subset)::text)) AND (c.product_type = '2A25'::bpchar)))) LEFT JOIN orbit_subset_product d ON ((((a.orbit = d.orbit) AND ((a.subset)::text = (d.subset)::text)) AND (d.product_type = '1C21'::bpchar))));


--
-- TOC entry 60 (OID 450016)
-- Name: collatedzproductswsub; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE collatedzproductswsub FROM PUBLIC;
GRANT SELECT ON TABLE collatedzproductswsub TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 61 (OID 450020)
-- Name: collatedmosaicswsub; Type: VIEW; Schema: public; Owner: morris
--

CREATE VIEW collatedmosaicswsub AS
    SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, min((b.filename)::text) AS "first", max((c.filename)::text) AS "second" FROM ((collatecolswsub a NATURAL JOIN coincident_mosaic b) LEFT JOIN coincident_mosaic c ON (((b.orbit = c.orbit) AND ((b.filename)::text <> (c.filename)::text)))) GROUP BY a.orbit, overpass_time, nominal, radar_id, subset;


--
-- TOC entry 62 (OID 450020)
-- Name: collatedmosaicswsub; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE collatedmosaicswsub FROM PUBLIC;
GRANT SELECT ON TABLE collatedmosaicswsub TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 63 (OID 451255)
-- Name: rawradar; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE rawradar (
    product character varying(15),
    radar_id character varying(15),
    nominal timestamp with time zone,
    filepath character varying(63),
    filename character varying(63) NOT NULL
);


--
-- TOC entry 64 (OID 451255)
-- Name: rawradar; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE rawradar FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE rawradar TO gvoper;
GRANT SELECT ON TABLE rawradar TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 65 (OID 510831)
-- Name: km_le_100_w_rain10; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE km_le_100_w_rain10 (
    event_num integer,
    radar_id character varying(15),
    orbit integer,
    overpass_time timestamp with time zone,
    nearest_distance integer,
    pct_overlap double precision,
    pct_overlap_conv double precision,
    pct_overlap_strat double precision,
    pct_overlap_rain_certain double precision
);


--
-- TOC entry 66 (OID 539124)
-- Name: gvradar_fullpath; Type: VIEW; Schema: public; Owner: morris
--

CREATE VIEW gvradar_fullpath AS
    SELECT gvradar.product, gvradar.radar_id, gvradar.nominal, ((((('/data/gv_radar/finalQC_in/'::text || (gvradar.radar_id)::text) || '/'::text) || (gvradar.filepath)::text) || '/'::text) || (gvradar.filename)::text) AS fullpath FROM gvradar;


--
-- TOC entry 67 (OID 539124)
-- Name: gvradar_fullpath; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE gvradar_fullpath FROM PUBLIC;
GRANT SELECT ON TABLE gvradar_fullpath TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 68 (OID 596967)
-- Name: ovlp25_w_rain25; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE ovlp25_w_rain25 (
    radar_id character varying(15),
    orbit integer,
    overpass_time timestamp with time zone,
    pct_overlap double precision,
    pct_overlap_conv double precision,
    pct_overlap_strat double precision,
    pct_overlap_rain_certain double precision
);


--
-- TOC entry 69 (OID 596967)
-- Name: ovlp25_w_rain25; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE ovlp25_w_rain25 FROM PUBLIC;
GRANT SELECT ON TABLE ovlp25_w_rain25 TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 70 (OID 663349)
-- Name: sitedbzsums; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE sitedbzsums (
    w double precision,
    s double precision,
    n bigint,
    gvtype character(4),
    regime character varying(10),
    radar_id character varying(15),
    height double precision
);


--
-- TOC entry 71 (OID 663349)
-- Name: sitedbzsums; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE sitedbzsums FROM PUBLIC;
GRANT SELECT ON TABLE sitedbzsums TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 72 (OID 675876)
-- Name: dbzdiff_stats; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE dbzdiff_stats (
    gvtype character(4) NOT NULL,
    regime character varying(10) NOT NULL,
    radar_id character varying(15) NOT NULL,
    orbit integer NOT NULL,
    height double precision NOT NULL,
    meandiff double precision,
    diffstddev double precision,
    prmax double precision,
    gvmax double precision,
    prmean double precision,
    gvmean double precision,
    numpts integer
);


--
-- TOC entry 73 (OID 675876)
-- Name: dbzdiff_stats; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE dbzdiff_stats FROM PUBLIC;
GRANT SELECT ON TABLE dbzdiff_stats TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 74 (OID 767930)
-- Name: collatedgvproducts; Type: VIEW; Schema: public; Owner: morris
--

CREATE VIEW collatedgvproducts AS
    SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, (((((a.radar_id)::text || '/'::text) || (b.filepath)::text) || '/'::text) || (b.filename)::text) AS file2a55, (((((a.radar_id)::text || '/'::text) || (c.filepath)::text) || '/'::text) || (c.filename)::text) AS file2a54, (((((a.radar_id)::text || '/'::text) || (f.filepath)::text) || '/'::text) || (f.filename)::text) AS file2a53, (((((a.radar_id)::text || '/'::text) || (d.filepath)::text) || '/'::text) || (d.filename)::text) AS file1cuf, (((((a.radar_id)::text || '/'::text) || (e.filepath)::text) || '/'::text) || (e.filename)::text) AS file1c51 FROM (((((collatecolswsub a LEFT JOIN gvradar b ON ((((a.nominal = b.nominal) AND ((a.radar_id)::text = (b.radar_id)::text)) AND ((b.product)::text = '2A55'::text)))) LEFT JOIN gvradar c ON ((((a.nominal = c.nominal) AND ((a.radar_id)::text = (c.radar_id)::text)) AND ((c.product)::text = '2A54'::text)))) LEFT JOIN gvradar f ON ((((a.nominal = f.nominal) AND ((a.radar_id)::text = (f.radar_id)::text)) AND ((f.product)::text = '2A53'::text)))) LEFT JOIN gvradar d ON ((((a.nominal = d.nominal) AND ((a.radar_id)::text = (d.radar_id)::text)) AND ((d.product)::text = '1CUF'::text)))) LEFT JOIN gvradar e ON ((((a.nominal = e.nominal) AND ((a.radar_id)::text = (e.radar_id)::text)) AND ((e.product)::text = '1C51'::text))));


--
-- TOC entry 75 (OID 767930)
-- Name: collatedgvproducts; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE collatedgvproducts FROM PUBLIC;
GRANT SELECT ON TABLE collatedgvproducts TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 76 (OID 824100)
-- Name: collatedproductswsub; Type: VIEW; Schema: public; Owner: morris
--

CREATE VIEW collatedproductswsub AS
    SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, g.filename AS file2a53, b.filename AS file2a54, c.filename AS file2a55, d.filename AS file1c21, e.filename AS file2a23, f.filename AS file2a25, h.filename AS file2b31 FROM (((((((collatecolswsub a LEFT JOIN gvradar g ON ((((a.nominal = g.nominal) AND ((a.radar_id)::text = (g.radar_id)::text)) AND ((g.product)::text = '2A53'::text)))) LEFT JOIN gvradar b ON ((((a.nominal = b.nominal) AND ((a.radar_id)::text = (b.radar_id)::text)) AND ((b.product)::text = '2A54'::text)))) LEFT JOIN gvradar c ON ((((a.nominal = c.nominal) AND ((a.radar_id)::text = (c.radar_id)::text)) AND ((c.product)::text = '2A55'::text)))) LEFT JOIN orbit_subset_product d ON ((((a.orbit = d.orbit) AND ((a.subset)::text = (d.subset)::text)) AND (d.product_type = '1C21'::bpchar)))) LEFT JOIN orbit_subset_product e ON ((((a.orbit = e.orbit) AND ((a.subset)::text = (e.subset)::text)) AND (e.product_type = '2A23'::bpchar)))) LEFT JOIN orbit_subset_product f ON ((((a.orbit = f.orbit) AND ((a.subset)::text = (f.subset)::text)) AND (f.product_type = '2A25'::bpchar)))) LEFT JOIN orbit_subset_product h ON ((((a.orbit = h.orbit) AND ((a.subset)::text = (h.subset)::text)) AND (h.product_type = '2B31'::bpchar))));


--
-- TOC entry 77 (OID 824100)
-- Name: collatedproductswsub; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE collatedproductswsub FROM PUBLIC;
GRANT SELECT ON TABLE collatedproductswsub TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 78 (OID 824109)
-- Name: collatedprproductswsub; Type: VIEW; Schema: public; Owner: morris
--

CREATE VIEW collatedprproductswsub AS
    SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, d.filename AS file1c21, e.filename AS file2a23, f.filename AS file2a25, h.filename AS file2b31 FROM ((((collatecolswsub a LEFT JOIN orbit_subset_product d ON ((((a.orbit = d.orbit) AND ((a.subset)::text = (d.subset)::text)) AND (d.product_type = '1C21'::bpchar)))) LEFT JOIN orbit_subset_product e ON ((((a.orbit = e.orbit) AND ((a.subset)::text = (e.subset)::text)) AND (e.product_type = '2A23'::bpchar)))) LEFT JOIN orbit_subset_product f ON ((((a.orbit = f.orbit) AND ((a.subset)::text = (f.subset)::text)) AND (f.product_type = '2A25'::bpchar)))) LEFT JOIN orbit_subset_product h ON ((((a.orbit = h.orbit) AND ((a.subset)::text = (h.subset)::text)) AND (h.product_type = '2B31'::bpchar))));


--
-- TOC entry 79 (OID 824109)
-- Name: collatedprproductswsub; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE collatedprproductswsub FROM PUBLIC;
GRANT SELECT ON TABLE collatedprproductswsub TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 80 (OID 1523403)
-- Name: dbzdiff_stats_w_sfc; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE dbzdiff_stats_w_sfc (
    landtype character varying(10) NOT NULL,
    gvtype character(4) NOT NULL,
    regime character varying(10) NOT NULL,
    radar_id character varying(15) NOT NULL,
    orbit integer NOT NULL,
    height double precision NOT NULL,
    meandiff double precision,
    diffstddev double precision,
    prmax double precision,
    gvmax double precision,
    prmean double precision,
    gvmean double precision,
    numpts integer
);


--
-- TOC entry 81 (OID 1523403)
-- Name: dbzdiff_stats_w_sfc; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE dbzdiff_stats_w_sfc FROM PUBLIC;
GRANT SELECT ON TABLE dbzdiff_stats_w_sfc TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 82 (OID 1700953)
-- Name: dbzdiff_stats_by_dist; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE dbzdiff_stats_by_dist (
    rangecat integer NOT NULL,
    gvtype character(4) NOT NULL,
    regime character varying(10) NOT NULL,
    radar_id character varying(15) NOT NULL,
    orbit integer NOT NULL,
    height double precision NOT NULL,
    meandiff double precision,
    diffstddev double precision,
    prmax double precision,
    gvmax double precision,
    prmean double precision,
    gvmean double precision,
    numpts integer
);


--
-- TOC entry 83 (OID 1700953)
-- Name: dbzdiff_stats_by_dist; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE dbzdiff_stats_by_dist FROM PUBLIC;
GRANT SELECT ON TABLE dbzdiff_stats_by_dist TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 84 (OID 1963086)
-- Name: dbzdiff_stats_by_angle; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE dbzdiff_stats_by_angle (
    anglecat integer NOT NULL,
    gvtype character(4) NOT NULL,
    regime character varying(10) NOT NULL,
    radar_id character varying(15) NOT NULL,
    orbit integer NOT NULL,
    height double precision NOT NULL,
    meandiff double precision,
    diffstddev double precision,
    prmax double precision,
    gvmax double precision,
    prmean double precision,
    gvmean double precision,
    numpts integer
);


--
-- TOC entry 85 (OID 1963086)
-- Name: dbzdiff_stats_by_angle; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE dbzdiff_stats_by_angle FROM PUBLIC;
GRANT SELECT ON TABLE dbzdiff_stats_by_angle TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 86 (OID 2040687)
-- Name: pr_angle_cat_text; Type: TABLE; Schema: public; Owner: morris
--

CREATE TABLE pr_angle_cat_text (
    anglecat integer NOT NULL,
    angletext character varying(10)
);


--
-- TOC entry 87 (OID 2040687)
-- Name: pr_angle_cat_text; Type: ACL; Schema: public; Owner: morris
--

REVOKE ALL ON TABLE pr_angle_cat_text FROM PUBLIC;
GRANT SELECT ON TABLE pr_angle_cat_text TO PUBLIC;


SET SESSION AUTHORIZATION 'morris';

--
-- TOC entry 100 (OID 887744)
-- Name: gvradidx3; Type: INDEX; Schema: public; Owner: morris
--

CREATE INDEX gvradidx3 ON gvradar USING btree (nominal, radar_id, product);


--
-- TOC entry 91 (OID 20465)
-- Name: lineage_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY lineage
    ADD CONSTRAINT lineage_pkey PRIMARY KEY (relationship);


--
-- TOC entry 92 (OID 20478)
-- Name: instrument_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY instrument
    ADD CONSTRAINT instrument_pkey PRIMARY KEY (instrument_id);


--
-- TOC entry 93 (OID 20503)
-- Name: instrument_hierarchy_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY instrument_hierarchy
    ADD CONSTRAINT instrument_hierarchy_pkey PRIMARY KEY (parent_instrument_id, child_instrument_id);


--
-- TOC entry 94 (OID 22964)
-- Name: coincident_mosaic_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY coincident_mosaic
    ADD CONSTRAINT coincident_mosaic_pkey PRIMARY KEY (orbit, filename);


--
-- TOC entry 95 (OID 49357)
-- Name: overpass_event_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY overpass_event
    ADD CONSTRAINT overpass_event_pkey PRIMARY KEY (event_num);


--
-- TOC entry 96 (OID 49359)
-- Name: overpass_event_sat_id_key; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY overpass_event
    ADD CONSTRAINT overpass_event_sat_id_key UNIQUE (sat_id, radar_id, orbit);


--
-- TOC entry 97 (OID 52686)
-- Name: ctstatus_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY ctstatus
    ADD CONSTRAINT ctstatus_pkey PRIMARY KEY (datestamp);


--
-- TOC entry 99 (OID 90153)
-- Name: gvradar_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY gvradar
    ADD CONSTRAINT gvradar_pkey PRIMARY KEY (filename);


--
-- TOC entry 101 (OID 150321)
-- Name: fixed_instrument_location_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY fixed_instrument_location
    ADD CONSTRAINT fixed_instrument_location_pkey PRIMARY KEY (instrument_id, install_date);


--
-- TOC entry 102 (OID 154414)
-- Name: appstatus_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY appstatus
    ADD CONSTRAINT appstatus_pkey PRIMARY KEY (app_id, datestamp);


--
-- TOC entry 103 (OID 163764)
-- Name: metadata_parameter_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY metadata_parameter
    ADD CONSTRAINT metadata_parameter_pkey PRIMARY KEY (metadata_id);


--
-- TOC entry 104 (OID 167886)
-- Name: metadata_temp_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY metadata_temp
    ADD CONSTRAINT metadata_temp_pkey PRIMARY KEY (event_num, metadata_id);


--
-- TOC entry 105 (OID 180245)
-- Name: event_meta_numeric_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY event_meta_numeric
    ADD CONSTRAINT event_meta_numeric_pkey PRIMARY KEY (event_num, metadata_id);


--
-- TOC entry 107 (OID 283746)
-- Name: gvradarvolume_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY gvradarvolume
    ADD CONSTRAINT gvradarvolume_pkey PRIMARY KEY (volume_id);


--
-- TOC entry 106 (OID 283748)
-- Name: gvradarvolume_filename_key; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY gvradarvolume
    ADD CONSTRAINT gvradarvolume_filename_key UNIQUE (filename, start_time);


--
-- TOC entry 108 (OID 403884)
-- Name: productsubset_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY productsubset
    ADD CONSTRAINT productsubset_pkey PRIMARY KEY (sat_id, subset);


--
-- TOC entry 109 (OID 403902)
-- Name: siteproductsubset_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY siteproductsubset
    ADD CONSTRAINT siteproductsubset_pkey PRIMARY KEY (sat_id, subset, radar_id);


--
-- TOC entry 98 (OID 403942)
-- Name: orbit_subset_product_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY orbit_subset_product
    ADD CONSTRAINT orbit_subset_product_pkey PRIMARY KEY (sat_id, subset, orbit, product_type);


--
-- TOC entry 90 (OID 418336)
-- Name: uniqfilename; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY heldmosaic
    ADD CONSTRAINT uniqfilename UNIQUE (filename);


--
-- TOC entry 110 (OID 451258)
-- Name: rawradar_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY rawradar
    ADD CONSTRAINT rawradar_pkey PRIMARY KEY (filename);


--
-- TOC entry 111 (OID 675878)
-- Name: dbzdiff_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY dbzdiff_stats
    ADD CONSTRAINT dbzdiff_stats_pkey PRIMARY KEY (gvtype, regime, radar_id, orbit, height);


--
-- TOC entry 112 (OID 1523406)
-- Name: dbzdiff_stats_w_sfc_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY dbzdiff_stats_w_sfc
    ADD CONSTRAINT dbzdiff_stats_w_sfc_pkey PRIMARY KEY (landtype, gvtype, regime, radar_id, orbit, height);


--
-- TOC entry 113 (OID 1700955)
-- Name: dbzdiff_stats_by_dist_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY dbzdiff_stats_by_dist
    ADD CONSTRAINT dbzdiff_stats_by_dist_pkey PRIMARY KEY (rangecat, gvtype, regime, radar_id, orbit, height);


--
-- TOC entry 114 (OID 1963088)
-- Name: dbzdiff_stats_by_angle_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY dbzdiff_stats_by_angle
    ADD CONSTRAINT dbzdiff_stats_by_angle_pkey PRIMARY KEY (anglecat, gvtype, regime, radar_id, orbit, height);


--
-- TOC entry 115 (OID 2040689)
-- Name: pr_angle_cat_text_pkey; Type: CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY pr_angle_cat_text
    ADD CONSTRAINT pr_angle_cat_text_pkey PRIMARY KEY (anglecat);


--
-- TOC entry 116 (OID 20480)
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY instrument
    ADD CONSTRAINT "$1" FOREIGN KEY (parent_child) REFERENCES lineage(relationship);


--
-- TOC entry 117 (OID 20505)
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY instrument_hierarchy
    ADD CONSTRAINT "$1" FOREIGN KEY (parent_instrument_id) REFERENCES instrument(instrument_id);


--
-- TOC entry 118 (OID 20509)
-- Name: $2; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY instrument_hierarchy
    ADD CONSTRAINT "$2" FOREIGN KEY (child_instrument_id) REFERENCES instrument(instrument_id);


--
-- TOC entry 119 (OID 49361)
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY overpass_event
    ADD CONSTRAINT "$1" FOREIGN KEY (sat_id) REFERENCES instrument(instrument_id);


--
-- TOC entry 120 (OID 49365)
-- Name: $2; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY overpass_event
    ADD CONSTRAINT "$2" FOREIGN KEY (radar_id) REFERENCES instrument(instrument_id);


--
-- TOC entry 122 (OID 75892)
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY gvradartemp
    ADD CONSTRAINT "$1" FOREIGN KEY (radar_id) REFERENCES instrument(instrument_id);


--
-- TOC entry 123 (OID 130366)
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY gvradar
    ADD CONSTRAINT "$1" FOREIGN KEY (radar_id) REFERENCES instrument(instrument_id);


--
-- TOC entry 124 (OID 150323)
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY fixed_instrument_location
    ADD CONSTRAINT "$1" FOREIGN KEY (instrument_id) REFERENCES instrument(instrument_id);


--
-- TOC entry 125 (OID 167888)
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY metadata_temp
    ADD CONSTRAINT "$1" FOREIGN KEY (metadata_id) REFERENCES metadata_parameter(metadata_id);


--
-- TOC entry 126 (OID 168048)
-- Name: $2; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY metadata_temp
    ADD CONSTRAINT "$2" FOREIGN KEY (event_num) REFERENCES overpass_event(event_num);


--
-- TOC entry 127 (OID 180247)
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY event_meta_numeric
    ADD CONSTRAINT "$1" FOREIGN KEY (event_num) REFERENCES overpass_event(event_num);


--
-- TOC entry 128 (OID 180251)
-- Name: $2; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY event_meta_numeric
    ADD CONSTRAINT "$2" FOREIGN KEY (metadata_id) REFERENCES metadata_parameter(metadata_id);


--
-- TOC entry 129 (OID 403888)
-- Name: instr_fk; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY productsubset
    ADD CONSTRAINT instr_fk FOREIGN KEY (sat_id) REFERENCES instrument(instrument_id);


--
-- TOC entry 130 (OID 403904)
-- Name: instr_fk; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY siteproductsubset
    ADD CONSTRAINT instr_fk FOREIGN KEY (radar_id) REFERENCES instrument(instrument_id);


--
-- TOC entry 131 (OID 403908)
-- Name: subset_fk; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY siteproductsubset
    ADD CONSTRAINT subset_fk FOREIGN KEY (sat_id, subset) REFERENCES productsubset(sat_id, subset);


--
-- TOC entry 121 (OID 403945)
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: morris
--

ALTER TABLE ONLY orbit_subset_product
    ADD CONSTRAINT "$1" FOREIGN KEY (sat_id, subset) REFERENCES productsubset(sat_id, subset);


SET SESSION AUTHORIZATION 'postgres';

--
-- TOC entry 3 (OID 2200)
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'Standard public schema';


