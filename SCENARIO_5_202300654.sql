-- ============================================================
-- SCENARIO 5: Engineering Workshop Tool Loans
-- ============================================================

DROP TABLE IF EXISTS tool_loans CASCADE;
DROP TABLE IF EXISTS tools CASCADE;

-- 1. Create tables and insert sample data
CREATE TABLE tools (
    tool_id SERIAL PRIMARY KEY,
    tool_name VARCHAR(100) NOT NULL,
    available_quantity INT NOT NULL CHECK (available_quantity >= 0)
);

CREATE TABLE tool_loans (
    loan_id SERIAL PRIMARY KEY,
    tool_id INT REFERENCES tools(tool_id),
    student_number VARCHAR(20) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    status VARCHAR(20) DEFAULT 'ISSUED' -- 'ISSUED' or 'RETURNED'
);

INSERT INTO tools (tool_name, available_quantity) VALUES
('Digital Multimeter', 15),
('Oscilloscope', 2),
('Soldering Station', 0);

-- 2. IF ELSIF ELSE demo
DO $$
DECLARE
    v_qty INT;
    v_tool VARCHAR(100);
BEGIN
    SELECT tool_name, available_quantity INTO v_tool, v_qty FROM tools WHERE tool_id = 2;
    
    IF v_qty = 0 THEN
        RAISE NOTICE 'Tool % is unavailable.', v_tool;
    ELSIF v_qty <= 3 THEN
        RAISE NOTICE 'Tool % is low on stock (% left).', v_tool, v_qty;
    ELSE
        RAISE NOTICE 'Tool % is readily available (% left).', v_tool, v_qty;
    END IF;
END $$;

-- 3. WHILE loop and Numeric FOR loop
DO $$
DECLARE
    v_rem INT := 1;
BEGIN
    -- WHILE loop
    WHILE v_rem <= 3 LOOP
        RAISE NOTICE 'Workshop Safety Reminder %', v_rem;
        v_rem := v_rem + 1;
    END LOOP;

    -- FOR loop
    FOR t_insp IN 1..3 LOOP
        RAISE NOTICE 'Tool Inspection Number %', t_insp;
    END LOOP;
END $$;

-- 4. Create issue_tool procedure
CREATE OR REPLACE PROCEDURE issue_tool(
    p_tool_id INT,
    p_student_number VARCHAR(20),
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_qty INT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Tool quantity must be greater than zero. Provided: %', p_quantity;
    END IF;

    SELECT available_quantity INTO v_qty 
    FROM tools 
    WHERE tool_id = p_tool_id FOR UPDATE;

    IF v_qty IS NULL THEN
        RAISE EXCEPTION 'Tool ID % does not exist.', p_tool_id;
    ELSIF v_qty < p_quantity THEN
        RAISE NOTICE 'Issue failed: Stock is %, requested %.', v_qty, p_quantity;
    ELSE
        UPDATE tools 
        SET available_quantity = available_quantity - p_quantity 
        WHERE tool_id = p_tool_id;

        INSERT INTO tool_loans (tool_id, student_number, quantity, status)
        VALUES (p_tool_id, p_student_number, p_quantity, 'ISSUED');

        RAISE NOTICE 'Issued % unit(s) of Tool ID % to student %.', p_quantity, p_tool_id, p_student_number;
    END IF;
END;
$$;

-- 5. Call issue_tool
CALL issue_tool(1, '20233001', 3); -- Valid
CALL issue_tool(2, '20233002', 1); -- Valid
CALL issue_tool(2, '20233003', 5); -- Exceeds stock

SELECT * FROM tools;
SELECT * FROM tool_loans;

-- 6. Create return_tool procedure
CREATE OR REPLACE PROCEDURE return_tool(
    p_loan_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_tool_id INT;
    v_qty INT;
BEGIN
    SELECT status, tool_id, quantity INTO v_status, v_tool_id, v_qty
    FROM tool_loans 
    WHERE loan_id = p_loan_id FOR UPDATE;

    IF v_status IS NULL THEN
        RAISE NOTICE 'Tool loan ID % not found.', p_loan_id;
    ELSIF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Tool loan ID % already returned. Stock will not be added again.', p_loan_id;
    ELSE
        UPDATE tool_loans SET status = 'RETURNED' WHERE loan_id = p_loan_id;
        UPDATE tools SET available_quantity = available_quantity + v_qty WHERE tool_id = v_tool_id;
        RAISE NOTICE 'Tool loan ID % successfully returned.', p_loan_id;
    END IF;
END;
$$;

-- Call return_tool twice
CALL return_tool(1);
CALL return_tool(1);

-- 7. Explicit cursor for tools with low availability
DO $$
DECLARE
    cur_tools CURSOR FOR 
        SELECT tool_id, tool_name, available_quantity FROM tools WHERE available_quantity <= 3;
    v_rec RECORD;
BEGIN
    OPEN cur_tools;
    LOOP
        FETCH cur_tools INTO v_rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low Availability Tool -> % (Stock: %)', v_rec.tool_name, v_rec.available_quantity;
    END LOOP;
    CLOSE cur_tools;
END $$;

-- 8. Try to issue zero tools with EXCEPTION handling
DO $$
BEGIN
    CALL issue_tool(1, '20233004', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught expected exception: %', SQLERRM;
END $$;

-- 9. Final state query
SELECT * FROM tools;
SELECT * FROM tool_loans;