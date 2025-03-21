DECLARE
    v_sql CLOB;
    v_day VARCHAR2(10);
    v_last_day NUMBER;
BEGIN
    -- Base SQL query
    v_sql := 'SELECT      ASID.SD_ID, 
                          ASID.DET_SALE_TYPE, 
                          ASID.CALL_CUSTOMER_NAME CUSTOMER_NAME,
                          ASID.CALL_CUSTOMER_ID,
                          ASID.CUSTOMER_EMP_ID,
                          ASID.CREATED_ON'; 

    -- Get the number of days in the current month
    v_last_day := TO_NUMBER(TO_CHAR(LAST_DAY(SYSDATE), 'DD'));

    -- Loop through each day of the current month to dynamically add a column
   FOR i IN 1..v_last_day LOOP
        -- Format the day as 'DD-MM-YYYY'
        v_day := TO_CHAR(TRUNC(SYSDATE, 'MM') + (i - 1), 'DD-MM-YYYY');

        -- Append the dynamically generated column to the SQL query
        v_sql := v_sql || ', COALESCE(MAX(CASE WHEN TO_CHAR( ASID.CREATED_ON, ''DD-MM-YYYY'') = ''' || v_day || ''' THEN ''<i class="fa fa-check-square" style="color:green;"></i>'' END), '''') AS "' || v_day || '"';
    END LOOP;

    -- Append the rest of the query
    v_sql := v_sql ||   'from AB_SALE_INFO_DET ASID
                          LEFT join AB_SALE_INFO SI on SI.sale_id = ASID.SALE_ID
                            LEFT JOIN AB_UM_APPLICATION_USERS UAU ON UAU.USER_ID=SI.EMP_ID
                           LEFT JOIN  ab_setup_registration  ASR ON ASID.CUSTOMER_ID=ASR.SR_ID
                          LEFT JOIN AB_UM_APP_USER_ORG ORG ON ORG.USER_ID = UAU.USER_ID
                         




                     --WHERE ASID.DET_SALE_TYPE = ''CUSTOMER ASSIGN DET''
                      WHERE ASID.DET_SALE_TYPE = ''CALL CUSTOMER''
                      
                     AND   ASID.CUSTOMER_EMP_ID=nvl(:P140_SALE_OFFICER,null)
                        GROUP BY ASID.SD_ID, 
                          ASID.DET_SALE_TYPE, 
                          ASID.CALL_CUSTOMER_NAME,
                          ASID.CUSTOMER_EMP_ID,
                          ASID.CALL_CUSTOMER_ID,
                          ASID.CREATED_ON
                        ORDER BY ASID.CREATED_ON';

    -- Output the dynamic SQL for debugging
    DBMS_OUTPUT.PUT_LINE(v_sql); -- Debugging output

    -- Execute the dynamically built SQL query
    RETURN v_sql;
END;
==============================================================================================================================
DECLARE
    v_sql      CLOB;       -- For storing large SQL
    v_day      VARCHAR2(10);
    v_last_day NUMBER;
BEGIN
    -- Base SQL query
    v_sql := 'SELECT ASID.SD_ID, 
                     ASID.DET_SALE_TYPE, 
                    ASR.REG_NAME CUSTOMER_NAME,
                    ASID.REMARKS,
                    ASR.CONTACT_NUMBER,
                     ASID.CREATED_ON,
                     ASID.UPDATED_ON';

    -- Get the number of days in the current month
    v_last_day := TO_NUMBER(TO_CHAR(LAST_DAY(SYSDATE), 'DD'));

    -- Loop through each day of the current month to dynamically add a column
    FOR i IN 1..v_last_day LOOP
        -- Format the day as 'DD-MM-YYYY'
        v_day := TO_CHAR(TRUNC(SYSDATE, 'MM') + (i - 1), 'DD-MM-YYYY');

        -- Append the dynamically generated column to the SQL query
        v_sql := v_sql || ', COALESCE(MAX( CASE 
                           WHEN 
                           --TO_CHAR(ASID.CREATED_ON, ''DD-MM-YYYY'') = ''' || v_day || '''  OR 
                           TO_CHAR(ASID.UPDATED_ON, ''DD-MM-YYYY'') = ''' || v_day || ''' 
                           THEN ''<i class="fa fa-check-square" style="color:green;"></i>''
                           END), '''') AS "' || v_day || '"';
    END LOOP;

    -- Append the rest of the query
    v_sql := v_sql || ' FROM AB_SALE_INFO_DET ASID
                        LEFT JOIN AB_SALE_INFO SI ON SI.SALE_ID = ASID.SALE_ID
                        LEFT JOIN AB_UM_APPLICATION_USERS UAU ON UAU.USER_ID = SI.EMP_ID
                        LEFT JOIN AB_SETUP_REGISTRATION ASR ON ASID.CUSTOMER_ID = ASR.SR_ID
                        LEFT JOIN AB_UM_APP_USER_ORG ORG ON ORG.USER_ID = UAU.USER_ID
                        WHERE 
                        --ASID.DET_SALE_TYPE = ''CALL CUSTOMER'' OR 
                        ASID.DET_SALE_TYPE = ''CUSTOMER ASSIGN DET''
                        AND UAU.USER_ID = NVL(:GV_USER_ID, NULL)
                        GROUP BY ASID.SD_ID, 
                                 ASID.DET_SALE_TYPE, 
                                ASR.REG_NAME,
                                 ASID.REMARKS,
                                 ASR.CONTACT_NUMBER,
                                 ASID.CREATED_ON,
                                 ASID.UPDATED_ON
                        ORDER BY ASID.CREATED_ON';

    -- Output the dynamic SQL for debugging
    DBMS_OUTPUT.PUT_LINE(v_sql);

    -- Return the dynamically built SQL
    RETURN v_sql;
END;
=========================================
original query
DECLARE
    v_sql      CLOB;       -- For storing large SQL
    v_day      VARCHAR2(10);
    v_last_day NUMBER;
BEGIN
    -- Base SQL query
    v_sql := 'SELECT ASID.SD_ID, 
                     ASID.DET_SALE_TYPE, 
                    ASR.REG_NAME CUSTOMER_NAME,
                    ASID.REMARKS,
                    ASR.CONTACT_NUMBER,
                     ASID.CREATED_ON,
                     ASID.UPDATED_ON';

    -- Get the number of days in the current month
    v_last_day := TO_NUMBER(TO_CHAR(LAST_DAY(SYSDATE), 'DD'));

    -- Loop through each day of the current month to dynamically add a column
    FOR i IN 1..v_last_day LOOP
        -- Format the day as 'DD-MM-YYYY'
        v_day := TO_CHAR(TRUNC(SYSDATE, 'MM') + (i - 1), 'DD-MM-YYYY');

        -- Append the dynamically generated column to the SQL query
        v_sql := v_sql || ', COALESCE(MAX( CASE 
                           WHEN 
                           TO_CHAR(ASID.CREATED_ON, ''DD-MM-YYYY'') = ''' || v_day || '''  OR 
                           TO_CHAR(ASID.UPDATED_ON, ''DD-MM-YYYY'') = ''' || v_day || ''' 
                           THEN ''<i class="fa fa-check-square" style="color:green;"></i>''
                           END), '''') AS "' || v_day || '"';
    END LOOP;

    -- Append the rest of the query
    v_sql := v_sql || ' FROM AB_SALE_INFO_DET ASID
                        LEFT JOIN AB_SALE_INFO SI ON SI.SALE_ID = ASID.SALE_ID
                        LEFT JOIN AB_UM_APPLICATION_USERS UAU ON UAU.USER_ID = SI.EMP_ID
                        LEFT JOIN AB_SETUP_REGISTRATION ASR ON ASID.CUSTOMER_ID = ASR.SR_ID
                        LEFT JOIN AB_UM_APP_USER_ORG ORG ON ORG.USER_ID = UAU.USER_ID
                        WHERE 
                        --ASID.DET_SALE_TYPE = ''CALL CUSTOMER'' OR 
                        ASID.DET_SALE_TYPE = ''CUSTOMER ASSIGN DET''
                        AND UAU.USER_ID = NVL(:GV_USER_ID, NULL)
                        GROUP BY ASID.SD_ID, 
                                 ASID.DET_SALE_TYPE, 
                                ASR.REG_NAME,
                                 ASID.REMARKS,
                                 ASR.CONTACT_NUMBER,
                                 ASID.CREATED_ON,
                                 ASID.UPDATED_ON
                        ORDER BY ASID.CREATED_ON';

    -- Output the dynamic SQL for debugging
    DBMS_OUTPUT.PUT_LINE(v_sql);

    -- Return the dynamically built SQL
    RETURN v_sql;
END;
==========================================================
UPDATED QUERY 2/11/2024
DECLARE
    v_sql      CLOB;       -- For storing large SQL
    v_day      VARCHAR2(10);
    v_last_day NUMBER;
BEGIN
    -- Base SQL query
    v_sql := 'SELECT ASID.SD_ID, 
                     ASID.DET_SALE_TYPE, 
                    ASR.REG_NAME CUSTOMER_NAME,
                    ASID.REMARKS,
                    ASR.CONTACT_NUMBER,
                     ASID.CREATED_ON,
                     ASID.UPDATED_ON';

    -- Get the number of days in the current month
    v_last_day := TO_NUMBER(TO_CHAR(LAST_DAY(SYSDATE), 'DD'));

    -- Loop through each day of the current month to dynamically add a column
    FOR i IN 1..v_last_day LOOP
        -- Format the day as 'DD-MM-YYYY'
        v_day := TO_CHAR(TRUNC(SYSDATE, 'MM') + (i - 1), 'DD-MM-YYYY');

        -- Append the dynamically generated column to the SQL query
        v_sql := v_sql || ', COALESCE(MAX( CASE 
                           WHEN 
                           TO_CHAR(ASID.CREATED_ON, ''DD-MM-YYYY'') = ''' || v_day || '''  OR 
                           TO_CHAR(ASID.UPDATED_ON, ''DD-MM-YYYY'') = ''' || v_day || ''' 
                           THEN ''<i class="fa fa-check-square" style="color:green;"></i>''
                           END), '''') AS "' || v_day || '"';
    END LOOP;

    -- Append the rest of the query
    v_sql := v_sql || ' FROM AB_SALE_INFO_DET ASID
                        LEFT JOIN AB_SALE_INFO SI ON SI.SALE_ID = ASID.SALE_ID
                        LEFT JOIN AB_UM_APPLICATION_USERS UAU ON UAU.USER_ID = SI.EMP_ID
                        LEFT JOIN AB_SETUP_REGISTRATION ASR ON ASID.CUSTOMER_ID = ASR.SR_ID
                        LEFT JOIN AB_UM_APP_USER_ORG ORG ON ORG.USER_ID = UAU.USER_ID
                        WHERE 
                        --ASID.DET_SALE_TYPE = ''CALL CUSTOMER'' OR 
                        ASID.DET_SALE_TYPE = ''CUSTOMER ASSIGN DET''
                       -- AND UAU.USER_ID = NVL(:P140_SALE_OFFICER, NULL)
                       AND UAU.USER_ID = NVL(NVL(:P140_SALE_OFFICER, :P140_SALE_OFFICER),72)
                        AND ASID.STATUS = ''Y'' and ASID.REMARKS IS NOT NULL
                        GROUP BY ASID.SD_ID, 
                                 ASID.DET_SALE_TYPE, 
                                ASR.REG_NAME,
                                 ASID.REMARKS,
                                 ASR.CONTACT_NUMBER,
                                 ASID.CREATED_ON,
                                 ASID.UPDATED_ON
                        ORDER BY ASID.CREATED_ON';

    -- Output the dynamic SQL for debugging
   -- DBMS_OUTPUT.PUT_LINE(v_sql);

    -- Return the dynamically built SQL
    RETURN v_sql;
END;
=========================================================================
--new query add
DECLARE
    v_sql      CLOB;       -- For storing large SQL
    v_day      VARCHAR2(10);
    v_last_day NUMBER;
BEGIN
    -- Base SQL query
    v_sql := 'SELECT ASID.SD_ID, 
                     ASID.DET_SALE_TYPE, 
                    ASR.REG_NAME CUSTOMER_NAME,
                    ASID.REMARKS,
                    ASR.CONTACT_NUMBER,
                     ASID.CREATED_ON,
                     ASID.CREATED_BY,
                     ASID.UPDATED_ON';

    -- Get the number of days in the current month
    v_last_day := TO_NUMBER(TO_CHAR(LAST_DAY(SYSDATE), 'DD'));

    -- Loop through each day of the current month to dynamically add a column
    FOR i IN 1..v_last_day LOOP
        -- Format the day as 'DD-MM-YYYY'
        v_day := TO_CHAR(TRUNC(SYSDATE, 'MM') + (i - 1), 'DD-MM-YYYY');

        -- Append the dynamically generated column to the SQL query
        v_sql := v_sql || ', COALESCE(MAX( CASE 
                           WHEN 
                           TO_CHAR(ASID.CREATED_ON, ''DD-MM-YYYY'') = ''' || v_day || '''  OR 
                           TO_CHAR(ASID.UPDATED_ON, ''DD-MM-YYYY'') = ''' || v_day || ''' 
                           THEN ''<i class="fa fa-check-square" style="color:green;"></i>''
                           END), '''') AS "' || v_day || '"';
    END LOOP;

    -- Append the rest of the query
    v_sql := v_sql || ' FROM AB_SALE_INFO_DET ASID
                        LEFT JOIN AB_SALE_INFO SI ON SI.SALE_ID = ASID.SALE_ID
                        LEFT JOIN AB_UM_APPLICATION_USERS UAU ON UAU.USER_ID = SI.EMP_ID
                        LEFT JOIN AB_SETUP_REGISTRATION ASR ON ASID.CUSTOMER_ID = ASR.SR_ID
                        LEFT JOIN AB_UM_APP_USER_ORG ORG ON ORG.USER_ID = UAU.USER_ID
                        WHERE 
                        --ASID.DET_SALE_TYPE = ''CALL CUSTOMER'' OR 
                        ASID.DET_SALE_TYPE = ''CUSTOMER ASSIGN DET''
                       -- AND UAU.USER_ID = NVL(:P140_SALE_OFFICER, NULL)
                       AND UAU.USER_ID = NVL(NVL(:P140_SALE_OFFICER, :P140_SALE_OFFICER),72)
                        AND ASID.STATUS = ''Y'' and ASID.REMARKS IS NOT NULL
                        AND ASID.ORG_ID=:GV_ORG_ID
                        GROUP BY ASID.SD_ID, 
                                 ASID.DET_SALE_TYPE, 
                                ASR.REG_NAME,
                                 ASID.REMARKS,
                                 ASR.CONTACT_NUMBER,
                                 ASID.CREATED_ON,
                                 ASID.CREATED_BY,
                                 ASID.UPDATED_ON
                        ORDER BY ASID.CREATED_ON';

    -- Output the dynamic SQL for debugging
    --DBMS_OUTPUT.PUT_LINE(v_sql);

    -- Return the dynamically built SQL
   RETURN v_sql;
END;



