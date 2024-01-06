create or replace procedure compile_invalid_objects as
l_sql varchar2(4000);
BEGIN

  FOR L_REC IN (SELECT object_name, object_type,
               CASE WHEN OBJECT_TYPE = 'VIEW' THEN 1 
            WHEN OBJECT_TYPE='TRIGGER' THEN 2
            WHEN OBJECT_TYPE='FUNCTION' THEN 3
            WHEN OBJECT_TYPE='PROCEDURE' THEN 4
            WHEN OBJECT_TYPE = 'PACKAGE' THEN 6
            WHEN OBJECT_TYPE = 'PACKAGE BODY' THEN 7
            ELSE 8
            END COMPILE_ORDER
               FROM user_objects
               WHERE OBJECT_TYPE NOT LIKE 'MATERIAL%' AND status = 'INVALID'
               order by COMPILE_ORDER)
  LOOP
    l_sql := 'ALTER ' || replace(l_rec.object_type, 'PACKAGE BODY', 'PACKAGE') ||' "'||l_rec.object_name|| '" COMPILE';
    DBMS_OUTPUT.put_line( l_sql );
    EXECUTE IMMEDIATE l_sql;
  END LOOP;
END;