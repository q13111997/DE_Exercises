CREATE OR REPLACE FUNCTION fn_gen_string(
    p_userid TEXT,
	p_tablename TEXT
)
RETURNS TEXT AS
$$
DECLARE

    v_string TEXT;
	rec RECORD;
	v RECORD;

BEGIN

    IF EXISTS (
	    SELECT 1
		FROM t_config_rls
		WHERE userid = p_userid
		AND (tablename='*'
		OR (tablename=p_tablename AND (fieldname='*' OR value ='*')))
    ) THEN
	    RETURN '1=1';
	END IF;

	IF p_userid = 'ADV' THEN
	    FOR rec IN
		    (SELECT fieldname, value
			FROM t_config_rls
			WHERE userid = 'ADV')
		LOOP
			IF EXISTS (
				SELECT 1
				FROM information_schema.columns
				WHERE table_name = LOWER(p_tablename)
				AND column_name = LOWER(rec.fieldname)
			) THEN
				IF rec.Value LIKE '%\%%' ESCAPE '\' THEN
                    FOR v IN SELECT trim(val) AS v FROM regexp_split_to_table(rec.Value, ',') AS val LOOP
                        v_string := v_string || format('%I LIKE %L OR ', rec.FieldName, v.v);
                    END LOOP;
				ELSE
					v_string := v_string || format('%I IN (%s) OR ',
													rec.FieldName,
									                (SELECT string_agg(quote_literal(trim(val)), ',')
									                 FROM regexp_split_to_table(rec.Value, ',') AS val));
				END IF;
        	END IF;
		END LOOP;
	ELSE
		FOR rec IN
			(SELECT fieldname, value
			FROM t_config_rls
			WHERE userid = 'ADV')
		LOOP
			IF rec.Value LIKE '%\%%' ESCAPE '\' THEN
	            FOR v IN SELECT trim(val) AS v FROM regexp_split_to_table(rec.Value, ',') AS val LOOP
	                v_string := v_string || format('%I LIKE %L OR ', rec.FieldName, v.v);
	            END LOOP;
	        ELSE
	            v_string := v_string || format('%I IN (%s) OR ',
														rec.FieldName,
										                (SELECT string_agg(quote_literal(trim(val)), ',')
										                 FROM regexp_split_to_table(rec.Value, ',') AS val));
	        END IF;
		END LOOP;
	END IF;

	IF v_string <> '' THEN
		RETURN LEFT(v_string, LENGTH(v_string) - 4);
	ELSE
		RETURN '1=0';
	END IF;

END;
$$
LANGUAGE plpgsql;