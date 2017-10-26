CREATE TABLE ct_temp (
    orbit integer,
    radar_name character varying,
    radar_id character varying,
    overpass_time timestamp with time zone,
    proximity double precision
);


ALTER TABLE public.ct_temp OWNER TO morris;

REVOKE ALL ON TABLE ct_temp FROM PUBLIC;
REVOKE ALL ON TABLE ct_temp FROM morris;
GRANT ALL ON TABLE ct_temp TO morris;
GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE ct_temp TO PUBLIC;

CREATE TABLE heldmosaic (
    nominal timestamp without time zone,
    filename character varying
);


ALTER TABLE public.heldmosaic OWNER TO morris;

REVOKE ALL ON TABLE heldmosaic FROM PUBLIC;
REVOKE ALL ON TABLE heldmosaic FROM morris;
GRANT ALL ON TABLE heldmosaic TO morris;
GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE heldmosaic TO PUBLIC;
