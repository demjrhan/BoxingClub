SET SERVEROUT ON;
/*
RETRIEVE THE DETAILS OF A SPECIFIC BOXER, INCLUDING THEIR NAME,
AGE, WEIGHT CLASS, TRAINER, AND PERFORMANCE RECORD.
 */
SELECT BOXER.ID        as "B. ID",
       BOXER.NAME      as "B. NAME",
       BOXER.SURNAME   as "B. SURNAME",
       BOXER.AGE       as "B. AGE",
       BOXER.WEIGHT    as "B. WEIGHT",
       TRAINER.ID      as "T. ID",
       TRAINER.NAME    as "T. NAME",
       TRAINER.SURNAME as "T. SURNAME",
       TRAINER.AGE     as "T. AGE",
       RECORD.WINS     as "TOTAL WINS",
       RECORD.LOSES    as "TOTAL LOSES",
       RECORD.DRAW     as "TOTAL DRAWS"
FROM BOXER
         JOIN TRAINER ON BOXER.Trainer_ID = TRAINER.ID
         JOIN RECORD ON BOXER.ID = RECORD.ID;


/* CALCULATE THE AVERAGE AGE OF BOXERS IN EACH WEIGHT CLASS.
   THIS IS DONE BY SUBTRACTING THE YEAR OF BIRTH FROM THE CURRENT YEAR. */
SELECT WEIGHT_CLASS.NAME                                                        AS "WEIGHT_CLASS",
       ROUND(AVG(EXTRACT(YEAR FROM SYSDATE) - EXTRACT(YEAR FROM BOXER.AGE)), 2) AS "AVERAGE_AGE"
FROM BOXER
         JOIN WEIGHT_CLASS ON BOXER.WEIGHT_CLASS_ID = WEIGHT_CLASS.ID
GROUP BY WEIGHT_CLASS.NAME;


/* GET THE DETAILS OF MATCHES INCLUDING WINNER AND LOSER.
   IF MATCH ENDED DRAW OR SOME INJURY HAPPENED,
   THERE WILL BE NO LOSER OR WINNER, DUE TO THIS COLUMNS WILL BE NULL. */
SELECT MATCH.ID,
       MATCH.MATCH_DATE,
       MATCH.PLACE,
       MATCH.WIN_TYPE_ID   AS WINTYPE,
       WEIGHT_CLASS.NAME   AS WEIGHT_CLASS,
       FIRSTBOXER.NAME     AS FIRST_BOXER_NAME,
       FIRSTBOXER.SURNAME  AS FIRST_BOXER_SURNAME,
       SECONDBOXER.NAME    AS SECOND_BOXER_NAME,
       SECONDBOXER.SURNAME AS SECOND_BOXER_SURNAME,
       CASE
           WHEN MATCH.WIN_TYPE_ID IN (3, 4) THEN NULL
           ELSE MATCH.WINNER_ID
           END             AS WINNER_ID,
       CASE
           WHEN MATCH.WIN_TYPE_ID IN (3, 4) THEN NULL
           ELSE MATCH.LOSER_ID
           END             AS LOSER_ID
FROM MATCH
         JOIN BOXER FIRSTBOXER ON MATCH.BOXER_1_ID = FIRSTBOXER.ID
         JOIN BOXER SECONDBOXER ON MATCH.BOXER_2_ID = SECONDBOXER.ID
         JOIN WEIGHT_CLASS ON MATCH.WEIGHT_CLASS_ID = WEIGHT_CLASS.ID;


/* GET THE EACH SPONSOR FROM EACH BOXER. */

SELECT BOXER.ID AS BOXER_ID, BOXER.NAME AS BOXER_NAME, SPONSOR.NAME AS SPONSOR_NAME
FROM BOXER
         JOIN BOXER_SPONSOR ON BOXER.ID = BOXER_SPONSOR.BOXER_ID
         JOIN SPONSOR ON BOXER_SPONSOR.SPONSOR_ID = SPONSOR.ID;


/*
 GET THE EACH BOXERS WIN-LOSE RATE.
 */
SELECT BOXER.ID                                                         AS BOXER_ID,
       BOXER.NAME                                                       AS BOXER_NAME,
       BOXER.SURNAME                                                    AS BOXER_SURNAME,
       RECORD.MATCH_PLAYED,
       RECORD.WINS,
       RECORD.LOSES,
       CONCAT(ROUND((RECORD.WINS / RECORD.MATCH_PLAYED) * 100, 2), '%') AS WIN_LOSS_RATIO
FROM BOXER
         JOIN
     RECORD ON BOXER.ID = RECORD.ID
ORDER BY WIN_LOSS_RATIO DESC;


/*
INSTRUCTION 1: IF THERE IS A WINNER, GET CURRENT STATISTICS FOR THE WINNER.
INSTRUCTION 2: IF THERE IS A LOSER, GET CURRENT STATISTICS FOR THE LOSER.
INSTRUCTION 2.1: IF THERE IS NO WINNER OR LOSER (MATCH FINISHED IN A DRAW OR DUE TO INJURY), BOTH BOXERS' MATCH COUNT AND DRAW COUNT WILL INCREMENT.
INSTRUCTION 3: UPDATE THE WINNER'S RECORD WITH THE NEW MATCH RESULT.
INSTRUCTION 4: UPDATE THE LOSER'S RECORD WITH THE NEW MATCH RESULT.*/


CREATE OR REPLACE PROCEDURE UPDATE_BOXER_RECORD(WINNER_ID IN NUMBER, LOSER_ID IN NUMBER, BOXER_1_ID IN NUMBER,
                                                BOXER_2_ID IN NUMBER) IS


    WINNER_TOTAL_MATCH       NUMBER;
    WINNER_WIN_COUNT         NUMBER;
    WINNER_LOSE_COUNT        NUMBER;
    WINNER_DRAW_COUNT        NUMBER;
    LOSER_TOTAL_MATCH        NUMBER;
    LOSER_WIN_COUNT          NUMBER;
    LOSER_LOSE_COUNT         NUMBER;
    LOSER_DRAW_COUNT         NUMBER;
    FIRST_BOXER_TOTAL_MATCH  NUMBER;
    FIRST_BOXER_WIN_COUNT    NUMBER;
    FIRST_BOXER_LOSE_COUNT   NUMBER;
    FIRST_BOXER_DRAW_COUNT   NUMBER;
    SECOND_BOXER_TOTAL_MATCH NUMBER;
    SECOND_BOXER_WIN_COUNT   NUMBER;
    SECOND_BOXER_LOSE_COUNT  NUMBER;
    SECOND_BOXER_DRAW_COUNT  NUMBER;
    CURSOR WINNER_CURSOR IS
        SELECT MATCH_PLAYED, WINS, LOSES, DRAW
        FROM RECORD
        WHERE ID = WINNER_ID;
    CURSOR LOSER_CURSOR IS
        SELECT MATCH_PLAYED, WINS, LOSES, DRAW
        FROM RECORD
        WHERE ID = LOSER_ID;
    CURSOR BOXER_1_CURSOR IS
        SELECT MATCH_PLAYED, WINS, LOSES, DRAW
        FROM RECORD
        WHERE ID = BOXER_1_ID;
    CURSOR BOXER_2_CURSOR IS
        SELECT MATCH_PLAYED, WINS, LOSES, DRAW
        FROM RECORD
        WHERE ID = BOXER_2_ID;

BEGIN

    IF BOXER_1_ID IS NULL OR BOXER_2_ID IS NULL THEN
        RAISE_APPLICATION_ERROR(-1, 'BOXER ID CAN NOT BE NULL.');
    END IF;

    IF LOSER_ID IS NOT NULL THEN
         IF LOSER_ID NOT IN (BOXER_1_ID, BOXER_2_ID) THEN
            RAISE_APPLICATION_ERROR(-1, 'INVALID STATEMENT.');
        END IF;
         IF LOSER_ID = BOXER_1_ID AND LOSER_ID = BOXER_2_ID THEN
              RAISE_APPLICATION_ERROR(-1, 'INVALID STATEMENT.');
         END IF;
        IF WINNER_ID IS NULL THEN
            RAISE_APPLICATION_ERROR(-1, 'IF THERE IS NO WINNER, CANNOT BE LOSER.');
        END IF;
    END IF;

    IF WINNER_ID IS NOT NULL THEN
        IF WINNER_ID NOT IN (BOXER_1_ID, BOXER_2_ID) THEN
            RAISE_APPLICATION_ERROR(-1, 'INVALID STATEMENT.');
        END IF;
        IF WINNER_ID = BOXER_1_ID AND WINNER_ID = BOXER_2_ID THEN
              RAISE_APPLICATION_ERROR(-1, 'INVALID STATEMENT.');
         END IF;
        IF LOSER_ID IS NULL THEN
            RAISE_APPLICATION_ERROR(-1, 'IF THERE IS WINNER, LOSER CANNOT BE NULL.');
        END IF;
    END IF;


    IF WINNER_ID IS NULL THEN
        OPEN BOXER_1_CURSOR;
        FETCH BOXER_1_CURSOR INTO FIRST_BOXER_TOTAL_MATCH, FIRST_BOXER_WIN_COUNT, FIRST_BOXER_LOSE_COUNT, FIRST_BOXER_DRAW_COUNT;
        CLOSE BOXER_1_CURSOR;

        UPDATE RECORD
        SET MATCH_PLAYED = FIRST_BOXER_TOTAL_MATCH + 1,
            Wins         = FIRST_BOXER_WIN_COUNT,
            LOSES        = FIRST_BOXER_LOSE_COUNT,
            DRAW         = FIRST_BOXER_DRAW_COUNT + 1
        WHERE ID = BOXER_1_ID;
    ELSE
        OPEN WINNER_CURSOR;
        FETCH WINNER_CURSOR INTO WINNER_TOTAL_MATCH, WINNER_WIN_COUNT, WINNER_LOSE_COUNT, WINNER_DRAW_COUNT;
        CLOSE WINNER_CURSOR;

        UPDATE RECORD
        SET MATCH_PLAYED = WINNER_TOTAL_MATCH + 1,
            Wins         = WINNER_WIN_COUNT + 1,
            LOSES        = WINNER_LOSE_COUNT,
            DRAW         = WINNER_DRAW_COUNT
        WHERE ID = WINNER_ID;
    END IF;
    IF LOSER_ID IS NULL THEN
        OPEN BOXER_2_CURSOR;
        FETCH BOXER_2_CURSOR INTO SECOND_BOXER_TOTAL_MATCH, SECOND_BOXER_WIN_COUNT, SECOND_BOXER_LOSE_COUNT, SECOND_BOXER_DRAW_COUNT;
        CLOSE BOXER_2_CURSOR;

        UPDATE RECORD
        SET MATCH_PLAYED = SECOND_BOXER_TOTAL_MATCH + 1,
            Wins         = SECOND_BOXER_WIN_COUNT,
            LOSES        = SECOND_BOXER_LOSE_COUNT,
            DRAW         = SECOND_BOXER_DRAW_COUNT + 1
        WHERE ID = BOXER_2_ID;
    ELSE
        OPEN LOSER_CURSOR;
        FETCH LOSER_CURSOR INTO LOSER_TOTAL_MATCH, LOSER_WIN_COUNT, LOSER_LOSE_COUNT, LOSER_DRAW_COUNT;
        CLOSE LOSER_CURSOR;

        UPDATE RECORD
        SET MATCH_PLAYED = LOSER_TOTAL_MATCH + 1,
            Wins         = LOSER_WIN_COUNT,
            LOSES        = LOSER_LOSE_COUNT + 1,
            DRAW         = LOSER_DRAW_COUNT
        WHERE ID = LOSER_ID;
    END IF;


END;
/


BEGIN
    UPDATE_BOXER_RECORD(2, 1, 1, 2);
END;
/


/*  INSTRUCTION 1: CHECK IF THE TRAINER EXISTS.
    INSTRUCTION 2: IF TRAINER DOESN'T EXIST, LET THE USER KNOW.
    INSTRUCTION 3: CHECK IF THE  BOXER EXISTS.
    INSTRUCTION 4: IF BOXER DOESN'T EXIST, LET THE USER KNOW.
    INSTRUCTION 5: UPDATE BOXER'S TRAINER WITH THE GIVEN TRAINER ID IF TRAINER AND BOXER BOTH EXIST.
    INSTRUCTION 6: PROVIDE SUCCESSFUL  FEEDBACK.  */


CREATE OR REPLACE PROCEDURE ASSIGN_TRAINER_TO_BOXER(GIVEN_BOXER_ID IN NUMBER, GIVEN_TRAINER_ID IN NUMBER) IS

    TRAINER_COUNT NUMBER;
    TRAINER_NAME  VARCHAR2(100);
    BOXER_COUNT   NUMBER;
    BOXER_NAME    VARCHAR2(100);

BEGIN
    SELECT COUNT(*)
    INTO TRAINER_COUNT
    FROM TRAINER
    WHERE ID = GIVEN_TRAINER_ID;

    SELECT COUNT(*)
    INTO BOXER_COUNT
    FROM BOXER
    WHERE ID = GIVEN_BOXER_ID;


    IF TRAINER_COUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-1, 'THERE IS NO TRAINER WITH ID = ' || GIVEN_TRAINER_ID);

    ELSIF BOXER_COUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-1, 'THERE IS NO BOXER WITH ID = ' || GIVEN_BOXER_ID);


    ELSE

        SELECT NAME
        INTO BOXER_NAME
        FROM BOXER
        WHERE ID = GIVEN_BOXER_ID;

        SELECT NAME
        INTO TRAINER_NAME
        FROM TRAINER
        WHERE ID = GIVEN_TRAINER_ID;

        UPDATE BOXER
        SET TRAINER_ID = GIVEN_TRAINER_ID
        WHERE ID = GIVEN_BOXER_ID;
        DBMS_OUTPUT.PUT_LINE(TRAINER_NAME || '(T) assigned to = ' || BOXER_NAME || '(B)');
    END IF;
END;
/

BEGIN
    ASSIGN_TRAINER_TO_BOXER(1, 2);
END;
/


/*
INSTRUCTION 1: CHECK IF THE NEW TRAINER'S AGE IS LESS THAN 25.
INSTRUCTION 2: LET THE USER KNOW IF THE TRAINER'S AGE IS LESS THAN 25.
INSTRUCTION 3: ALLOW THE INSERTION OR UPDATE IF THE AGE IS ACCEPTABLE. */


CREATE OR REPLACE TRIGGER CHECK_MIN_TRAINER_AGE
    BEFORE INSERT OR UPDATE
    ON TRAINER
    FOR EACH ROW
DECLARE
    BIRTH_YEAR NUMBER;
BEGIN
    BIRTH_YEAR := EXTRACT(YEAR FROM :NEW.AGE);

    IF EXTRACT(YEAR FROM SYSDATE) - BIRTH_YEAR < 25 THEN
        RAISE_APPLICATION_ERROR(-1, 'TRAINER MUST BE OLDER THAN 25');
    END IF;
END;
/

INSERT INTO TRAINER (ID, NAME, SURNAME, AGE)
VALUES (6, 'TEST', 'TEST', TO_DATE('2024-01-01', 'YYYY-MM-DD'));


/*

INSTRUCTION 1: CALCULATES AND ASSIGNS THE WEIGHT_CLASS_ID FOR THE BOXER.
INSTRUCTION 2: DETERMINES THE BOXER'S WEIGHT CLASS BASED ON THEIR WEIGHT.
INSTRUCTION 3: UPDATES THE BOXER'S WEIGHT_CLASS_ID WITH THE APPROPRIATE VALUE.
INSTRUCTION 4: IF BOXER'S WEIGHT IS TOO LESS OR TOO MUCH, USER WILL GET AN ERROR AND NOTHING WILL BE INSERTED, UPDATED.
*/


CREATE OR REPLACE TRIGGER UPDATE_BOXER_WEIGHT_CLASS
    BEFORE INSERT OR UPDATE
    ON BOXER
    FOR EACH ROW
DECLARE
    CORRECT_WEIGHT_CLASS INT;
BEGIN

    SELECT ID
    INTO CORRECT_WEIGHT_CLASS
    FROM WEIGHT_CLASS
    WHERE :NEW.WEIGHT >= LOWER_LIMIT
      AND :NEW.WEIGHT <= UPPER_LIMIT
        FETCH FIRST 1 ROW ONLY;

    IF CORRECT_WEIGHT_CLASS IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001,
                                'THERE IS NO SUITABLE WEIGHT_CLASS FOR THIS BOXER.');
    ELSE
        IF :NEW.WEIGHT_CLASS_ID IS NULL OR :NEW.WEIGHT_CLASS_ID != CORRECT_WEIGHT_CLASS
        THEN
            :NEW.WEIGHT_CLASS_ID := CORRECT_WEIGHT_CLASS;
        END IF;
    END IF;
END;
/


SELECT *
FROM BOXER;
INSERT INTO BOXER (ID, NAME, SURNAME, AGE, WEIGHT, WEIGHT_CLASS_ID, TRAINER_ID)
VALUES (12, 'TEST', 'TEST', TO_DATE('1988-05-01', 'YYYY-MM-DD'), 156, 1, 1);
