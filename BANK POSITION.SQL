SELECT 
    RN,
    ACCOUNT_ID,
    ACCOUNT_NAME,
    TRANSACTION_DATE,
    TR_DESCRIPTION,
    OPENING_AMOUNT,
    SOURCE,

    
    CASE 
       -- WHEN SOURCE = 'Opening' THEN NVL(OPENING_AMOUNT, 0)
        WHEN SOURCE = 'Receiving' THEN RECEIVING_AMOUNT
        WHEN SOURCE = 'Transfer In' THEN TRANSFER_IN_AMOUNT
        ELSE 0
    END AS DEBIT_AMOUNT,

    
    CASE 
        WHEN SOURCE = 'Approved' THEN APPROVED_AMOUNT
        WHEN SOURCE = 'Transfer Out' THEN TRANSFER_OUT_AMOUNT
        ELSE 0
    END AS CREDIT_AMOUNT,

  
    SUM(
        CASE 
            WHEN SOURCE = 'Opening' THEN NVL(OPENING_AMOUNT, 0)
            WHEN SOURCE = 'Receiving' THEN NVL(RECEIVING_AMOUNT, 0)
            WHEN SOURCE = 'Transfer In' THEN NVL(TRANSFER_IN_AMOUNT, 0)
            WHEN SOURCE = 'Approved' THEN -NVL(APPROVED_AMOUNT, 0)
            WHEN SOURCE = 'Transfer Out' THEN -NVL(TRANSFER_OUT_AMOUNT, 0)
            ELSE NVL(OPENING_AMOUNT, 0)
        END
    ) OVER (
        PARTITION BY ACCOUNT_ID 
        ORDER BY RN
    ) AS RUNNING_BALANCE

FROM (
    SELECT 
        ACCOUNT_ID,
        ACCOUNT_NAME,
        TRANSACTION_DATE,
        TR_DESCRIPTION,
        OPENING_AMOUNT,
        RECEIVING_AMOUNT,
        TRANSFER_IN_AMOUNT,
        APPROVED_AMOUNT,
        TRANSFER_OUT_AMOUNT,
        SOURCE,

        CASE 
            WHEN SOURCE = 'Opening' THEN 0
            ELSE ROW_NUMBER() OVER (
                PARTITION BY ACCOUNT_ID 
                ORDER BY TRANSACTION_DATE, 
                         CASE SOURCE
                            WHEN 'Receiving' THEN 1
                            WHEN 'Transfer In' THEN 2
                            WHEN 'Approved' THEN 3
                            WHEN 'Transfer Out' THEN 4
                            ELSE 0
                         END
            )
        END AS RN

    FROM ( 

        -- 0. Opening
       SELECT 
            AC.ACCOUNT_ID,
            NULL AS ACCOUNT_NAME,
            NULL AS TRANSACTION_DATE,
           -- FT.TR_DATE AS TRANSACTION_DATE,
           NULL TR_DESCRIPTION,
           NVL(FT.TR_AMOUNT, 0) AS OPENING_AMOUNT,
            NULL RECEIVING_AMOUNT,
            NULL AS TRANSFER_IN_AMOUNT,
            NULL AS APPROVED_AMOUNT,
            NULL AS TRANSFER_OUT_AMOUNT,
            'Opening' AS SOURCE
        FROM AB_FIN_TRANSACTION FT
        LEFT JOIN AB_FIN_TRANSACTION_DET FTD ON FTD.TR_ID = FT.TR_ID AND FTD.STATUS = 'Y'
        LEFT JOIN ( 
              SELECT   
                  MAX(AFC.ACCOUNT_TITLE) AS ACCOUNT_NAME,
                  --||' - '|| ACT.REG_DISCRIPTION    AS ACCOUNT_NAME  ,
                    ACT.SR_ID ACCOUNT_ID   ,
                    ACT.BANK_ID                  
               FROM   AB_FIN_COA AFC
              LEFT  JOIN  AB_SETUP_REGISTRATION ACT ON ACT.SR_ID = AFC.SUB_ACCOUNT_TYPE
              LEFT JOIN AB_SETUP_REGISTRATION BNK  ON BNK.SR_ID = ACT.BANK_ID AND BNK.REG_TYPE = 'BANK'
            WHERE 
                   ACT.REG_TYPE = '624'
               AND ACT.ORG_ID = :GV_ORG_ID
                AND ACT.REG_STATUS='Y'
            
                 GROUP BY 
                   ACT.SR_ID   ,
                    ACT.BANK_ID 
        ) AC ON AC.ACCOUNT_ID = FT.ACCOUNT_ID
        WHERE TR_TYPE = 625
          AND FT.ORG_ID = :GV_ORG_ID
          AND FT.STATUS = 'Y'
           AND FT.ACCOUNT_ID = :P510_ID
        -- AND FT.TR_DATE BETWEEN NVL(TO_DATE(:P510_FROM_DATE, 'DD-MON-YYYY'), FT.TR_DATE)
                        ---  AND NVL(TO_DATE(:P510_TO_DATE, 'DD-MON-YYYY'), TRUNC(FT.TR_DATE))

                       
         

        UNION ALL

        -- 🔽 1. Receiving
        
    SELECT
        REC.ACCOUNT_ID,
        AN.ACCOUNT_NAME,
        REC.TR_DATE AS TRANSCATION_DATE,
        RECD.TR_DESCRIPTION || ' Transcation Amount ('||NVL(TO_NUMBER(REGEXP_REPLACE(RECD.RECEIVING_AMOUNT, '[^0-9.]', '')),RECD.TRD_AMOUNT)||')' TR_DESCRIPTION,
        NULL AS OPENING_AMOUNT,
        NVL(TO_NUMBER(REGEXP_REPLACE(RECEIVING_AMOUNT, '[^0-9.]', '')), RECD.TRD_AMOUNT) AS RECEIVING_AMOUNT,
        NULL AS TRANSFER_IN_AMOUNT,
        NULL AS APPROVED_AMOUNT,
        NULL AS TRANSFER_OUT_AMOUNT,
        'Receiving' AS SOURCE
    FROM
        AB_FIN_TRANSACTION REC
        left JOIN AB_FIN_TRANSACTION_DET RECD ON RECD.TR_ID = REC.TR_ID
        left JOIN ( 
           SELECT   
                MAX(AFC.ACCOUNT_TITLE) AS ACCOUNT_NAME,
                    ACT.SR_ID ACCOUNT_ID   ,
                    ACT.BANK_ID                  
               FROM   AB_FIN_COA AFC
              LEFT  JOIN  AB_SETUP_REGISTRATION ACT ON ACT.SR_ID = AFC.SUB_ACCOUNT_TYPE
              LEFT JOIN AB_SETUP_REGISTRATION BNK  ON BNK.SR_ID = ACT.BANK_ID AND BNK.REG_TYPE = 'BANK'
            WHERE 
                   ACT.REG_TYPE = '624'
               AND ACT.ORG_ID = :GV_ORG_ID
                
                AND ACT.REG_STATUS='Y'
                   GROUP BY 
                   ACT.SR_ID   ,
                    ACT.BANK_ID ) AN ON AN.ACCOUNT_ID = REC.ACCOUNT_ID
        
    WHERE
        REC.TR_TYPE = 626
        AND REC.ORG_ID = :GV_ORG_ID
        AND REC.STATUS = 'Y'
        AND RECD.STATUS = 'Y'
           AND REC.ACCOUNT_ID = :P510_ID
          AND TRUNC(REC.TR_DATE) BETWEEN NVL(TO_DATE(:P510_FROM_DATE, 'DD-MON-YYYY'), TRUNC(REC.TR_DATE))
                                    AND NVL(TO_DATE(:P510_TO_DATE, 'DD-MON-YYYY'), TRUNC(REC.TR_DATE))





        UNION ALL

        -- 2. Transfer In

SELECT 
            AC.ACCOUNT_ID,
            AC.ACCOUNT_NAME,
            FT.TR_DATE AS TRANSACTION_DATE,
          --  'Funda transfer from '|| AC.ACCOUNT_NAME  AS TR_DESCRIPTION,
    'Funds transfer from ' || MAX(CASE WHEN AC.ACCOUNT_ID=FTD.TO_ACCOUNT_ID AND AC.REG_TYPE IN ('BANK LOV','624') THEN AC.ACCOUNT_NAME   END) AS TR_DESCRIPTION,

       
             NULL AS OPENING_AMOUNT,
            NULL AS RECEIVING_AMOUNT,
            NVL(FTD.TRANS_AMOUNT, 0) AS TRANSFER_IN_AMOUNT,
            NULL AS APPROVED_AMOUNT,
            NULL AS TRANSFER_OUT_AMOUNT,
            'Transfer In' AS SOURCE
        FROM AB_FIN_TRANSACTION FT
        JOIN AB_FIN_TRANSACTION_DET FTD ON FTD.TR_ID = FT.TR_ID AND FTD.STATUS = 'Y'
        JOIN (
              SELECT   
                 MAX(AFC.ACCOUNT_TITLE) AS ACCOUNT_NAME,
                 ACT.REG_TYPE,
                    ACT.SR_ID ACCOUNT_ID   ,
                    ACT.BANK_ID                  
               FROM   AB_FIN_COA AFC
              LEFT  JOIN  AB_SETUP_REGISTRATION ACT ON ACT.SR_ID = AFC.SUB_ACCOUNT_TYPE
              LEFT JOIN AB_SETUP_REGISTRATION BNK  ON BNK.SR_ID = ACT.BANK_ID AND BNK.REG_TYPE = 'BANK'
            WHERE 
                   ACT.REG_TYPE = '624'
               AND ACT.ORG_ID = :GV_ORG_ID
                AND ACT.REG_STATUS='Y'
                   GROUP BY   
                   ACT.SR_ID ,ACT.REG_TYPE,
                    ACT.BANK_ID 
        ) AC ON AC.ACCOUNT_ID IN( FTD.TO_ACCOUNT_ID, FTD.FROM_ACCOUNT_ID)
        WHERE FT.TR_TYPE = 622 AND FT.ORG_ID = :GV_ORG_ID AND FT.STATUS = 'Y'
          AND FTD.TO_ACCOUNT_ID = :P510_ID
          AND TRUNC(FT.TR_DATE) BETWEEN NVL(TO_DATE(:P510_FROM_DATE, 'DD-MON-YYYY'), TRUNC(FT.TR_DATE))
                                    AND NVL(TO_DATE(:P510_TO_DATE, 'DD-MON-YYYY'), TRUNC(FT.TR_DATE))
    GROUP BY 
     AC.ACCOUNT_ID,
    AC.ACCOUNT_NAME,
    FT.TR_DATE,
    FTD.TR_DESCRIPTION,
    FTD.RECEIVING_AMOUNT,
    FTD.TRD_AMOUNT,
    FTD.TRANS_AMOUNT

        UNION ALL

        --  3. Approved
        SELECT 
            AC.ACCOUNT_ID,
            AC.ACCOUNT_NAME,
            TRD.TRD_DATE AS TRANSACTION_DATE,
             TRD.TR_DESCRIPTION || ' Transcation Amount ('||NVL(TO_NUMBER(REGEXP_REPLACE(TRD.RECEIVING_AMOUNT, '[^0-9.]', '')),TRD.TRD_AMOUNT)||')' TR_DESCRIPTION,
             NULL AS OPENING_AMOUNT,
            NULL AS RECEIVING_AMOUNT,
            NULL AS TRANSFER_IN_AMOUNT,
            NVL(TRD.TRD_AMOUNT, 0) AS APPROVED_AMOUNT,
            NULL AS TRANSFER_OUT_AMOUNT,
            'Approved' AS SOURCE
        FROM AB_FIN_TRANSACTION_DET TRD
        JOIN AB_FIN_COA COA ON COA.COA_ID = TRD.COA_IDD
        JOIN (
               SELECT   
                 MAX(AFC.ACCOUNT_TITLE) AS ACCOUNT_NAME,
                  --||' - '|| ACT.REG_DISCRIPTION    AS ACCOUNT_NAME  ,
                    ACT.SR_ID ACCOUNT_ID   ,
                    ACT.BANK_ID                  
               FROM   AB_FIN_COA AFC
              LEFT  JOIN  AB_SETUP_REGISTRATION ACT ON ACT.SR_ID = AFC.SUB_ACCOUNT_TYPE
              LEFT JOIN AB_SETUP_REGISTRATION BNK  ON BNK.SR_ID = ACT.BANK_ID AND BNK.REG_TYPE = 'BANK'
            WHERE 
                   ACT.REG_TYPE = '624'
               AND ACT.ORG_ID = :GV_ORG_ID
                AND ACT.REG_STATUS='Y'
                   GROUP BY 
                   ACT.SR_ID   ,
                    ACT.BANK_ID 
        ) AC ON AC.ACCOUNT_ID = COA.SUB_ACCOUNT_TYPE
        WHERE TRD.TRD_TYPE = 632 AND TRD.ORG_ID = :GV_ORG_ID AND TRD.STATUS = 'Y'
          AND COA.SUB_ACCOUNT_TYPE = :P510_ID
          AND TRUNC(TRD.TRD_DATE) BETWEEN NVL(TO_DATE(:P510_FROM_DATE, 'DD-MON-YYYY'), TRUNC(TRD.TRD_DATE))
                                     AND NVL(TO_DATE(:P510_TO_DATE, 'DD-MON-YYYY'), TRUNC(TRD.TRD_DATE))

        UNION ALL

        --  4. Transfer Out
        SELECT 
            AC.ACCOUNT_ID,
            AC.ACCOUNT_NAME,
            FT.TR_DATE AS TRANSACTION_DATE,
          -- 'Funda transfer from '|| AC.ACCOUNT_NAME  AS TR_DESCRIPTION, 

       'Funds transfer from ' || CASE WHEN AC.ACCOUNT_ID=FTD.FROM_ACCOUNT_ID AND AC.REG_TYPE IN ('BANK LOV','624') THEN AC.ACCOUNT_NAME   END AS TR_DESCRIPTION,

            NULL AS OPENING_AMOUNT,
            NULL AS RECEIVING_AMOUNT,
            NULL AS TRANSFER_IN_AMOUNT,
            NULL AS APPROVED_AMOUNT,
            NVL(FTD.TRANS_AMOUNT, 0) AS TRANSFER_OUT_AMOUNT,
            'Transfer Out' AS SOURCE
        FROM AB_FIN_TRANSACTION FT
        JOIN AB_FIN_TRANSACTION_DET FTD ON FTD.TR_ID = FT.TR_ID AND FTD.STATUS = 'Y'
        JOIN (
             SELECT   
                  MAX(AFC.ACCOUNT_TITLE) AS ACCOUNT_NAME,
                   ACT.REG_TYPE,
                    ACT.SR_ID ACCOUNT_ID   ,
                    ACT.BANK_ID                  
               FROM   AB_FIN_COA AFC
              LEFT  JOIN  AB_SETUP_REGISTRATION ACT ON ACT.SR_ID = AFC.SUB_ACCOUNT_TYPE
              LEFT JOIN AB_SETUP_REGISTRATION BNK  ON BNK.SR_ID = ACT.BANK_ID AND BNK.REG_TYPE = 'BANK'
            WHERE 
                   ACT.REG_TYPE = '624'
               AND ACT.ORG_ID = :GV_ORG_ID
                AND ACT.REG_STATUS='Y'
                  GROUP BY  ACT.REG_TYPE,
                   ACT.SR_ID   ,
                    ACT.BANK_ID 
        ) AC ON AC.ACCOUNT_ID in (FTD.FROM_ACCOUNT_ID , FTD.TO_ACCOUNT_ID)
        WHERE FT.TR_TYPE = 622 AND FT.ORG_ID = :GV_ORG_ID AND FT.STATUS = 'Y'
          AND FTD.FROM_ACCOUNT_ID = :P510_ID
          AND TRUNC(FT.TR_DATE) BETWEEN NVL(TO_DATE(:P510_FROM_DATE, 'DD-MON-YYYY'), TRUNC(FT.TR_DATE))
                                    AND NVL(TO_DATE(:P510_TO_DATE, 'DD-MON-YYYY'), TRUNC(FT.TR_DATE))
        
    --     GROUP BY 
    -- AC.ACCOUNT_ID,
    -- AC.ACCOUNT_NAME,
    -- FT.TR_DATE,
    -- NVL(FTD.TRANS_AMOUNT, 0),
    -- 'Transfer Out'

    )
) 

where ACCOUNT_ID = NVL(:P510_ID,ACCOUNT_ID)
ORDER BY  RN, TRANSACTION_DATE ASC


------------------------------------------------------------------------------------------------------------------------------------------------- add manaual voucher 
SELECT 
    RN,
    ACCOUNT_ID,
    ACCOUNT_NAME,
    TRANSACTION_DATE,
    TR_DESCRIPTION,
    OPENING_AMOUNT,
    SOURCE,

    
    CASE 
       -- WHEN SOURCE = 'Opening' THEN NVL(OPENING_AMOUNT, 0)
        WHEN SOURCE = 'Receiving' THEN RECEIVING_AMOUNT
        WHEN SOURCE = 'Transfer In' THEN TRANSFER_IN_AMOUNT
        ELSE 0
    END AS DEBIT_AMOUNT,

    
    CASE 
        WHEN SOURCE = 'Approved' THEN APPROVED_AMOUNT
        WHEN SOURCE = 'Transfer Out' THEN TRANSFER_OUT_AMOUNT
        WHEN SOURCE = 'Manual'      THEN MANUAL_VOUCHER_AMOUNT
        ELSE 0
    END AS CREDIT_AMOUNT,

  
    SUM(
        CASE 
            WHEN SOURCE = 'Opening' THEN NVL(OPENING_AMOUNT, 0)
            WHEN SOURCE = 'Receiving' THEN NVL(RECEIVING_AMOUNT, 0)
            WHEN SOURCE = 'Transfer In' THEN NVL(TRANSFER_IN_AMOUNT, 0)
            WHEN SOURCE = 'Approved' THEN -NVL(APPROVED_AMOUNT, 0)
            WHEN SOURCE = 'Transfer Out' THEN -NVL(TRANSFER_OUT_AMOUNT, 0)
             WHEN SOURCE = 'Manual'      THEN -NVL(MANUAL_VOUCHER_AMOUNT,0)
            ELSE NVL(OPENING_AMOUNT, 0)
        END
    ) OVER (
        PARTITION BY ACCOUNT_ID 
        ORDER BY RN
    ) AS RUNNING_BALANCE

FROM (
    SELECT 
        ACCOUNT_ID,
        ACCOUNT_NAME,
        TRANSACTION_DATE,
        TR_DESCRIPTION,
        OPENING_AMOUNT,
        RECEIVING_AMOUNT,
        TRANSFER_IN_AMOUNT,
        APPROVED_AMOUNT,
        TRANSFER_OUT_AMOUNT,
        MANUAL_VOUCHER_AMOUNT,
        SOURCE,

        CASE 
            WHEN SOURCE = 'Opening' THEN 0
            ELSE ROW_NUMBER() OVER (
                PARTITION BY ACCOUNT_ID 
                ORDER BY TRANSACTION_DATE, 
                         CASE SOURCE
                            WHEN 'Receiving' THEN 1
                            WHEN 'Transfer In' THEN 2
                            WHEN 'Approved' THEN 3
                            WHEN 'Transfer Out' THEN 4
                            WHEN 'Manual'   THEN 5 
                            ELSE 0
                         END
            )
        END AS RN

    FROM ( 

        -- 0. Opening
       SELECT 
            AC.ACCOUNT_ID,
            NULL AS ACCOUNT_NAME,
            NULL AS TRANSACTION_DATE,
           -- FT.TR_DATE AS TRANSACTION_DATE,
           NULL TR_DESCRIPTION,
           NVL(FT.TR_AMOUNT, 0) AS OPENING_AMOUNT,
            NULL RECEIVING_AMOUNT,
            NULL AS TRANSFER_IN_AMOUNT,
            NULL AS APPROVED_AMOUNT,
            NULL AS TRANSFER_OUT_AMOUNT,
            NULL AS MANUAL_VOUCHER_AMOUNT,
            'Opening' AS SOURCE
        FROM AB_FIN_TRANSACTION FT
        LEFT JOIN AB_FIN_TRANSACTION_DET FTD ON FTD.TR_ID = FT.TR_ID AND FTD.STATUS = 'Y'
        LEFT JOIN ( 
              SELECT   
                  MAX(AFC.ACCOUNT_TITLE) AS ACCOUNT_NAME,
                  --||' - '|| ACT.REG_DISCRIPTION    AS ACCOUNT_NAME  ,
                    ACT.SR_ID ACCOUNT_ID   ,
                    ACT.BANK_ID                  
               FROM   AB_FIN_COA AFC
              LEFT  JOIN  AB_SETUP_REGISTRATION ACT ON ACT.SR_ID = AFC.SUB_ACCOUNT_TYPE
              LEFT JOIN AB_SETUP_REGISTRATION BNK  ON BNK.SR_ID = ACT.BANK_ID AND BNK.REG_TYPE = 'BANK'
            WHERE 
                   ACT.REG_TYPE = '624'
               AND ACT.ORG_ID = :GV_ORG_ID
                AND ACT.REG_STATUS='Y'
            
                 GROUP BY 
                   ACT.SR_ID   ,
                    ACT.BANK_ID 
        ) AC ON AC.ACCOUNT_ID = FT.ACCOUNT_ID
        WHERE TR_TYPE = 625
          AND FT.ORG_ID = :GV_ORG_ID
          AND FT.STATUS = 'Y'
           AND FT.ACCOUNT_ID = :P510_ID
        -- AND FT.TR_DATE BETWEEN NVL(TO_DATE(:P510_FROM_DATE, 'DD-MON-YYYY'), FT.TR_DATE)
                        ---  AND NVL(TO_DATE(:P510_TO_DATE, 'DD-MON-YYYY'), TRUNC(FT.TR_DATE))

                       
         

        UNION ALL

        -- 🔽 1. Receiving
        
    SELECT
        REC.ACCOUNT_ID,
        AN.ACCOUNT_NAME,
        REC.TR_DATE AS TRANSCATION_DATE,
        RECD.TR_DESCRIPTION || ' Transcation Amount ('||NVL(TO_NUMBER(REGEXP_REPLACE(RECD.RECEIVING_AMOUNT, '[^0-9.]', '')),RECD.TRD_AMOUNT)||')' TR_DESCRIPTION,
        NULL AS OPENING_AMOUNT,
        NVL(TO_NUMBER(REGEXP_REPLACE(RECEIVING_AMOUNT, '[^0-9.]', '')), RECD.TRD_AMOUNT) AS RECEIVING_AMOUNT,
        NULL AS TRANSFER_IN_AMOUNT,
        NULL AS APPROVED_AMOUNT,
        NULL AS TRANSFER_OUT_AMOUNT,
        NULL AS MANUAL_VOUCHER_AMOUNT,
        'Receiving' AS SOURCE
    FROM
        AB_FIN_TRANSACTION REC
        left JOIN AB_FIN_TRANSACTION_DET RECD ON RECD.TR_ID = REC.TR_ID
        left JOIN ( 
           SELECT   
                MAX(AFC.ACCOUNT_TITLE) AS ACCOUNT_NAME,
                    ACT.SR_ID ACCOUNT_ID   ,
                    ACT.BANK_ID                  
               FROM   AB_FIN_COA AFC
              LEFT  JOIN  AB_SETUP_REGISTRATION ACT ON ACT.SR_ID = AFC.SUB_ACCOUNT_TYPE
              LEFT JOIN AB_SETUP_REGISTRATION BNK  ON BNK.SR_ID = ACT.BANK_ID AND BNK.REG_TYPE = 'BANK'
            WHERE 
                   ACT.REG_TYPE = '624'
               AND ACT.ORG_ID = :GV_ORG_ID
                
                AND ACT.REG_STATUS='Y'
                   GROUP BY 
                   ACT.SR_ID   ,
                    ACT.BANK_ID ) AN ON AN.ACCOUNT_ID = REC.ACCOUNT_ID
        
    WHERE
        REC.TR_TYPE = 626
        AND REC.ORG_ID = :GV_ORG_ID
        AND REC.STATUS = 'Y'
        AND RECD.STATUS = 'Y'
           AND REC.ACCOUNT_ID = :P510_ID
          AND TRUNC(REC.TR_DATE) BETWEEN NVL(TO_DATE(:P510_FROM_DATE, 'DD-MON-YYYY'), TRUNC(REC.TR_DATE))
                                    AND NVL(TO_DATE(:P510_TO_DATE, 'DD-MON-YYYY'), TRUNC(REC.TR_DATE))





        UNION ALL

        -- 2. Transfer In

SELECT 
            AC.ACCOUNT_ID,
            AC.ACCOUNT_NAME,
            FT.TR_DATE AS TRANSACTION_DATE,
          --  'Funda transfer from '|| AC.ACCOUNT_NAME  AS TR_DESCRIPTION,
    'Funds transfer from ' || MAX(CASE WHEN AC.ACCOUNT_ID=FTD.TO_ACCOUNT_ID AND AC.REG_TYPE IN ('BANK LOV','624') THEN AC.ACCOUNT_NAME   END) AS TR_DESCRIPTION,

       
             NULL AS OPENING_AMOUNT,
            NULL AS RECEIVING_AMOUNT,
            NVL(FTD.TRANS_AMOUNT, 0) AS TRANSFER_IN_AMOUNT,
            NULL AS APPROVED_AMOUNT,
            NULL AS TRANSFER_OUT_AMOUNT,
            NULL AS MANUAL_VOUCHER_AMOUNT,
            'Transfer In' AS SOURCE
        FROM AB_FIN_TRANSACTION FT
        JOIN AB_FIN_TRANSACTION_DET FTD ON FTD.TR_ID = FT.TR_ID AND FTD.STATUS = 'Y'
        JOIN (
              SELECT   
                 MAX(AFC.ACCOUNT_TITLE) AS ACCOUNT_NAME,
                 ACT.REG_TYPE,
                    ACT.SR_ID ACCOUNT_ID   ,
                    ACT.BANK_ID                  
               FROM   AB_FIN_COA AFC
              LEFT  JOIN  AB_SETUP_REGISTRATION ACT ON ACT.SR_ID = AFC.SUB_ACCOUNT_TYPE
              LEFT JOIN AB_SETUP_REGISTRATION BNK  ON BNK.SR_ID = ACT.BANK_ID AND BNK.REG_TYPE = 'BANK'
            WHERE 
                   ACT.REG_TYPE = '624'
               AND ACT.ORG_ID = :GV_ORG_ID
                AND ACT.REG_STATUS='Y'
                   GROUP BY   
                   ACT.SR_ID ,ACT.REG_TYPE,
                    ACT.BANK_ID 
        ) AC ON AC.ACCOUNT_ID IN( FTD.TO_ACCOUNT_ID, FTD.FROM_ACCOUNT_ID)
        WHERE FT.TR_TYPE = 622 AND FT.ORG_ID = :GV_ORG_ID AND FT.STATUS = 'Y'
          AND FTD.TO_ACCOUNT_ID = :P510_ID
          AND TRUNC(FT.TR_DATE) BETWEEN NVL(TO_DATE(:P510_FROM_DATE, 'DD-MON-YYYY'), TRUNC(FT.TR_DATE))
                                    AND NVL(TO_DATE(:P510_TO_DATE, 'DD-MON-YYYY'), TRUNC(FT.TR_DATE))
    GROUP BY 
     AC.ACCOUNT_ID,
    AC.ACCOUNT_NAME,
    FT.TR_DATE,
    FTD.TR_DESCRIPTION,
    FTD.RECEIVING_AMOUNT,
    FTD.TRD_AMOUNT,
    FTD.TRANS_AMOUNT

        UNION ALL

        --  3. Approved
        SELECT 
            AC.ACCOUNT_ID,
            AC.ACCOUNT_NAME,
            TRD.TRD_DATE AS TRANSACTION_DATE,
             TRD.TR_DESCRIPTION || ' Transcation Amount ('||NVL(TO_NUMBER(REGEXP_REPLACE(TRD.RECEIVING_AMOUNT, '[^0-9.]', '')),TRD.TRD_AMOUNT)||')' TR_DESCRIPTION,
             NULL AS OPENING_AMOUNT,
            NULL AS RECEIVING_AMOUNT,
            NULL AS TRANSFER_IN_AMOUNT,
            NVL(TRD.TRD_AMOUNT, 0) AS APPROVED_AMOUNT,
            NULL AS TRANSFER_OUT_AMOUNT,
            NULL AS MANUAL_VOUCHER_AMOUNT,
            'Approved' AS SOURCE
        FROM AB_FIN_TRANSACTION_DET TRD
        JOIN AB_FIN_COA COA ON COA.COA_ID = TRD.COA_IDD
        JOIN (
               SELECT   
                 MAX(AFC.ACCOUNT_TITLE) AS ACCOUNT_NAME,
                  --||' - '|| ACT.REG_DISCRIPTION    AS ACCOUNT_NAME  ,
                    ACT.SR_ID ACCOUNT_ID   ,
                    ACT.BANK_ID                  
               FROM   AB_FIN_COA AFC
              LEFT  JOIN  AB_SETUP_REGISTRATION ACT ON ACT.SR_ID = AFC.SUB_ACCOUNT_TYPE
              LEFT JOIN AB_SETUP_REGISTRATION BNK  ON BNK.SR_ID = ACT.BANK_ID AND BNK.REG_TYPE = 'BANK'
            WHERE 
                   ACT.REG_TYPE = '624'
               AND ACT.ORG_ID = :GV_ORG_ID
                AND ACT.REG_STATUS='Y'
                   GROUP BY 
                   ACT.SR_ID   ,
                    ACT.BANK_ID 
        ) AC ON AC.ACCOUNT_ID = COA.SUB_ACCOUNT_TYPE
        WHERE TRD.TRD_TYPE = 632 AND TRD.ORG_ID = :GV_ORG_ID AND TRD.STATUS = 'Y'
          AND COA.SUB_ACCOUNT_TYPE = :P510_ID
          AND TRUNC(TRD.TRD_DATE) BETWEEN NVL(TO_DATE(:P510_FROM_DATE, 'DD-MON-YYYY'), TRUNC(TRD.TRD_DATE))
                                     AND NVL(TO_DATE(:P510_TO_DATE, 'DD-MON-YYYY'), TRUNC(TRD.TRD_DATE))

        UNION ALL

        --  4. Transfer Out
        SELECT 
            AC.ACCOUNT_ID,
            AC.ACCOUNT_NAME,
            FT.TR_DATE AS TRANSACTION_DATE,
          'Funds transfer from ' || CASE WHEN AC.ACCOUNT_ID=FTD.FROM_ACCOUNT_ID AND AC.REG_TYPE IN ('BANK LOV','624') THEN AC.ACCOUNT_NAME   END AS TR_DESCRIPTION,
            NULL AS OPENING_AMOUNT,
            NULL AS RECEIVING_AMOUNT,
            NULL AS TRANSFER_IN_AMOUNT,
            NULL AS APPROVED_AMOUNT,
            NVL(FTD.TRANS_AMOUNT, 0) AS TRANSFER_OUT_AMOUNT,
            NULL AS MANUAL_VOUCHER_AMOUNT,
            'Transfer Out' AS SOURCE
        FROM AB_FIN_TRANSACTION FT
        JOIN AB_FIN_TRANSACTION_DET FTD ON FTD.TR_ID = FT.TR_ID AND FTD.STATUS = 'Y'
        JOIN (
             SELECT   
                  MAX(AFC.ACCOUNT_TITLE) AS ACCOUNT_NAME,
                   ACT.REG_TYPE,
                    ACT.SR_ID ACCOUNT_ID   ,
                    ACT.BANK_ID                  
               FROM   AB_FIN_COA AFC
              LEFT  JOIN  AB_SETUP_REGISTRATION ACT ON ACT.SR_ID = AFC.SUB_ACCOUNT_TYPE
              LEFT JOIN AB_SETUP_REGISTRATION BNK  ON BNK.SR_ID = ACT.BANK_ID AND BNK.REG_TYPE = 'BANK'
            WHERE 
                   ACT.REG_TYPE = '624'
               AND ACT.ORG_ID = :GV_ORG_ID
                AND ACT.REG_STATUS='Y'
                  GROUP BY  ACT.REG_TYPE,
                   ACT.SR_ID   ,
                    ACT.BANK_ID 
        ) AC ON AC.ACCOUNT_ID in (FTD.FROM_ACCOUNT_ID , FTD.TO_ACCOUNT_ID)
        WHERE FT.TR_TYPE = 622 AND FT.ORG_ID = :GV_ORG_ID AND FT.STATUS = 'Y'
          AND FTD.FROM_ACCOUNT_ID = :P510_ID
          AND TRUNC(FT.TR_DATE) BETWEEN NVL(TO_DATE(:P510_FROM_DATE, 'DD-MON-YYYY'), TRUNC(FT.TR_DATE))
                                    AND NVL(TO_DATE(:P510_TO_DATE, 'DD-MON-YYYY'), TRUNC(FT.TR_DATE))
        
   
                                 UNION ALL

          

    SELECT 
            AC.ACCOUNT_ID,
            AC.ACCOUNT_NAME,
            TR.TR_DATE AS TRANSACTION_DATE,
            TRD.TR_DESCRIPTION || ' Transcation Amount ('||NVL(TO_NUMBER(REGEXP_REPLACE(TRD.RECEIVING_AMOUNT, '[^0-9.]', '')),TRD.TRD_AMOUNT)||')' TR_DESCRIPTION,
              NULL AS OPENING_AMOUNT,
            NULL AS RECEIVING_AMOUNT,
            NULL AS TRANSFER_IN_AMOUNT,
            NULL AS APPROVED_AMOUNT,
            NULL AS TRANSFER_OUT_AMOUNT,
            NVL(TRD.CR_AMOUNT, 0) MANUAL_VOUCHER_AMOUNT,
            'Manual' AS SOURCE
    FROM
                  AB_FIN_TRANSACTION TR
             JOIN AB_FIN_TRANSACTION_DET TRD ON TR.TR_ID = TRD.TR_ID
        LEFT JOIN AB_FIN_COA COA ON COA.COA_ID = TRD.COA_IDD AND COA.STATUS = 'Y'
        LEFT JOIN AB_SETUP_REGISTRATION SR ON SR.SR_ID = TRD.COA_IDD
             JOIN  (     SELECT
                  APP_IDS INOVICE_ID
            FROM
                  AB_USER_ACTION_APPROVAL
            WHERE
                     APPROVAL_STATUS='AUDIT APPROVED'
                AND  STATUS='Y'
            GROUP BY
                           APP_IDS  )  UA ON UA.INOVICE_ID=TR.TR_ID
          JOIN (
             SELECT   
                  MAX(AFC.ACCOUNT_TITLE) AS ACCOUNT_NAME,
                   ACT.REG_TYPE,
                    ACT.SR_ID ACCOUNT_ID   ,
                    ACT.BANK_ID                  
               FROM   AB_FIN_COA AFC
              LEFT  JOIN  AB_SETUP_REGISTRATION ACT ON ACT.SR_ID = AFC.SUB_ACCOUNT_TYPE
              LEFT JOIN AB_SETUP_REGISTRATION BNK  ON BNK.SR_ID = ACT.BANK_ID AND BNK.REG_TYPE = 'BANK'
            WHERE 
                   ACT.REG_TYPE = '624'
               AND ACT.ORG_ID = :GV_ORG_ID
                AND ACT.REG_STATUS='Y'
                  GROUP BY  ACT.REG_TYPE,
                   ACT.SR_ID   ,
                    ACT.BANK_ID 
        )  AC ON AC.ACCOUNT_ID = COA.SUB_ACCOUNT_TYPE
    WHERE
            -- TR.TR_TYPE IN (653,662,635)
            TR.TR_TYPE IN (635)
        AND TR.ORG_ID = :GV_ORG_ID
        AND TR.STATUS = 'Y'
        AND INOVICE_ID IS NOT NULL
         AND COA.SUB_ACCOUNT_TYPE = :P510_ID
        AND TRUNC(TR.TR_DATE) BETWEEN NVL(TO_DATE(:P510_FROM_DATE, 'DD-MON-YYYY'), TRUNC(TR.TR_DATE))
                                     AND NVL(TO_DATE(:P510_TO_DATE, 'DD-MON-YYYY'), TRUNC(TR.TR_DATE))

    )
) 

where ACCOUNT_ID = NVL(:P510_ID,ACCOUNT_ID)
ORDER BY  RN, TRANSACTION_DATE ASC





















