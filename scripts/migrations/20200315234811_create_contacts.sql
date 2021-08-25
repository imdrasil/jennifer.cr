-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

CREATE TABLE public.test_contacts (
    id integer NOT NULL,
    name character varying(30),
    age integer DEFAULT 0,
    tags integer[],
    ballance numeric,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    description text,
    user_id integer
);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP TABLE public.test_contacts;
