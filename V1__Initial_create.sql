-- here
CREATE TABLE test_user (
 name VARCHAR(25) NOT NULL,
 PRIMARY KEY(name)
);

-- PL/SQL block
CREATE TRIGGER test_trig AFTER insert ON test_user
BEGIN
   UPDATE test_user SET name = CONCAT(name, ' triggered');
END;
/

-- Placeholder
INSERT INTO test_user (name) VALUES ('Mr. T');
