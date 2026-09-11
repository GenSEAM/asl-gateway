(module asl-gateway/tests/server-test
  :d "Unit tests for L7 cognitive gateway server: think block quarantine, verbal ESH interception, and turn inspection."
  :x [test-extract-think-blocks
      test-detect-esh-violation
      test-inspect-completion-clean-turn
      test-inspect-completion-esh-rejection
      test-inspect-completion-quarantine
      run-tests]
  :i [(server :a srv)])

(df test-extract-think-blocks [] -> Bool
  :d "Verifies <think> block is extracted and separated from UI stream."
  (let [(raw "<think>Planning the solution step by step</think>Here is the completed code.")
        (res (srv/extract-think-blocks raw))
        (think-part (pair-first res))
        (ui-part (pair-second res))]
    (do
      (assert (= think-part "Planning the solution step by step") "Think content must match")
      (assert (= ui-part "Here is the completed code.") "UI content must be stripped of think tags")
      true)))

(df test-detect-esh-violation [] -> Bool
  :d "Verifies detection of ungrounded verbal claims of test passage."
  (do
    (assert (srv/detect-esh-violation "I ran the suite and all 5 tests pass cleanly.") "Must detect all 5 tests pass")
    (assert (srv/detect-esh-violation "Done! All tests pass.") "Must detect all tests pass")
    (assert (srv/detect-esh-violation "The gate passes cleanly without issues.") "Must detect gate passes cleanly")
    (assert (not (srv/detect-esh-violation "Here is the diff for reviewing.")) "Normal progress statement must not be flagged")
    true))

(df test-inspect-completion-clean-turn [] -> Bool
  :d "Verifies valid turn with tool calls passes inspection."
  (let [(raw "(:call :tool \"bash\" :cmd \"asl test\")")
        (verdict (srv/inspect-completion-turn raw true))]
    (do
      (assert (.-allowed verdict) "Clean turn must be allowed")
      (assert (= (list-length (.-tool-calls verdict)) 1) "Tool call must be extracted")
      (assert (= (.-quarantined-think verdict) "") "No think block in raw text")
      true)))

(df test-inspect-completion-esh-rejection [] -> Bool
  :d "Verifies verbal ESH claim without verified execution is blocked."
  (let [(raw "The refactor is done and all tests pass cleanly.")
        (verdict (srv/inspect-completion-turn raw false))]
    (do
      (assert (not (.-allowed verdict)) "Turn must be rejected due to ESH violation")
      (assert (string-contains? (.-rejection-reason verdict) "ESH violation") "Rejection reason must reference ESH")
      (assert (string-contains? (.-clean-output verdict) "Action blocked") "Clean output must be blocked notice")
      true)))

(df test-inspect-completion-quarantine [] -> Bool
  :d "Verifies CoT is quarantined while user text is preserved."
  (let [(raw "<think>Internal scratchpad</think>Final answer.")
        (verdict (srv/inspect-completion-turn raw true))]
    (do
      (assert (.-allowed verdict) "Turn must be allowed")
      (assert (= (.-quarantined-think verdict) "Internal scratchpad") "CoT must be quarantined")
      (assert (= (.-clean-output verdict) "Final answer.") "User output must match")
      true)))

(df run-tests [] -> Bool
  :d "Runs all server inspection tests."
  (and (test-extract-think-blocks)
       (and (test-detect-esh-violation)
            (and (test-inspect-completion-clean-turn)
                 (and (test-inspect-completion-esh-rejection)
                      (test-inspect-completion-quarantine))))))
