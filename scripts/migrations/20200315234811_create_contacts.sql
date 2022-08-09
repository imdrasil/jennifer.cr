-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

CREATE TABLE test_contacts (
    id integer NOT NULL,
    name character varying(30),
    age integer DEFAULT 0,
    ballance numeric,
    created_at timestamp,
    updated_at timestamp,
    description text,
    user_id integer
);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP TABLE test_contacts;
