CREATE OR REPLACE TRIGGER ind5_main
AFTER CREATE ON SCHEMA
DECLARE
    TYPE column_name_type IS TABLE OF user_tab_cols.column_name%TYPE;
    v_cols column_name_type;
    v_dyn_str VARCHAR(2048) := 
           'CREATE OR REPLACE TRIGGER ind5_' || SYS.DICTIONARY_OBJ_NAME || '_trg'
        || ' BEFORE INSERT OR UPDATE ON ' || SYS.DICTIONARY_OBJ_NAME
        || ' FOR EACH ROW'
        || ' BEGIN'
        || ' :NEW."USER" := SYS.LOGIN_USER;'
        || ' :NEW."TIME" := SYSDATE;'
        || q'! :NEW."OPERATION" := CASE WHEN INSERTING THEN 'INSERTING' WHEN UPDATING THEN 'UPDATING' END;!'
        || ' END;';
    e_columns EXCEPTION;
BEGIN
    IF SYS.DICTIONARY_OBJ_TYPE = 'TABLE' THEN
        EXECUTE IMMEDIATE 
            q'!SELECT column_name FROM user_tab_cols WHERE table_name = '!' || SYS.DICTIONARY_OBJ_NAME || q'!'!'
            BULK COLLECT INTO v_cols;
        FOR i IN v_cols.FIRST..v_cols.LAST LOOP
            IF v_cols(i) IN ('USER', 'TIME', 'OPERATION') THEN
                RAISE e_columns;
            END IF;
        END LOOP;
        EXECUTE IMMEDIATE
                       'ALTER TABLE ' || SYS.DICTIONARY_OBJ_NAME
                    || ' ADD ("USER" VARCHAR2(128),' 
                    || ' "TIME" TIMESTAMP, "OPERATION" VARCHAR2(9))';
        DBMS_SCHEDULER.CREATE_JOB (
            job_name           => 'ind5_' || SYS.DICTIONARY_OBJ_NAME || 'job',
            job_type           => 'PLSQL_BLOCK',
            job_action         => 
                   'BEGIN' 
                || q'! EXECUTE IMMEDIATE q'?!' || v_dyn_str || q'!?';!'
                || ' END;',
            start_date         => SYSTIMESTAMP + INTERVAL '1' SECOND,
            enabled            => TRUE
        );
    END IF;
EXCEPTION
    WHEN e_columns THEN 
        DBMS_OUTPUT.PUT_LINE('Trigger ind5_main ERROR:');
        DBMS_OUTPUT.PUT_LINE('   Not a suitable table for DML tracing!');
END ind5_main;
/
DROP TRIGGER ind5_main;
ALTER TRIGGER ind5_main DISABLE;
/
/*  --testing
SET SERVEROUTPUT ON;
/
CREATE TABLE w000w (c1 NUMBER, c2 VARCHAR2(40));
DESC w000w;
INSERT ALL
    INTO w000w (c1, c2) VALUES (1, 'aboba')
    INTO w000w (c1, c2) VALUES (2, 'boba')
    INTO w000w (c1, c2) VALUES (3, 'coca')
    INTO w000w (c1, c2) VALUES (4, 'doda')
SELECT 1 FROM dual;
SELECT * FROM w000w;
UPDATE w000w SET c1 = 10 WHERE c1 = 1;
SELECT * FROM w000w;
DROP TABLE w000w;
/
CREATE TABLE wooow (c1 NUMBER, c2 VARCHAR2(40), "USER" VARCHAR2(128));
DESC wooow;
DROP TABLE wooow;
*/
