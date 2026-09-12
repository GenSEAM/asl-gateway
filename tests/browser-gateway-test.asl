(module asl-gateway/tests/browser-gateway-test
  :d "Unit tests for In-Browser & Local Model Inference Gateway (WebGPU/Wasm/Ollama)."
  :x [test-browser-think-quarantine
      test-browser-esh-interception
      test-browser-clean-turn
      test-json-to-asn-toolcall-conversion
      test-format-browser-wire-payload
      run-tests]
  :i [(browser-gateway :a bgw)])

(df test-browser-think-quarantine [] -> Bool
  :d "Verifies CoT quarantine inside browser execution stream"
  (let [(raw "<think>WebGPU reasoning scratchpad</think>Here is the clean reply.")
        (res (bgw/extract-browser-think-blocks raw))
        (think-part (pair-first res))
        (ui-part (pair-second res))]
    (do
      (assert (= think-part "WebGPU reasoning scratchpad") "Think content must match")
      (assert (= ui-part "Here is the clean reply.") "UI content must be clean")
      true)))

(df test-browser-esh-interception [] -> Bool
  :d "Verifies detection of ungrounded verbal claims in browser turn"
  (do
    (assert (bgw/detect-browser-esh-violation "I ran all 5 tests pass") "Must detect all 5 tests pass")
    (assert (bgw/detect-browser-esh-violation "verified that gate passes cleanly") "Must detect gate passes cleanly")
    (assert (not (bgw/detect-browser-esh-violation "Processing inference turn...")) "Normal progress must not flag")
    true))

(df test-browser-clean-turn [] -> Bool
  :d "Verifies valid turn passes inspection in browser context"
  (let [(raw "(:call :tool \"bash\" :cmd \"asl test\")")
        (verdict (bgw/inspect-browser-turn raw true))]
    (do
      (assert (.-allowed verdict) "Clean turn must be allowed")
      (assert (= (list-length (.-tool-calls verdict)) 1) "Tool call must be extracted")
      true)))

(df test-json-to-asn-toolcall-conversion [] -> Bool
  :d "Verifies converting JSON tool call to compact canonical ASN tool call"
  (let [(res (bgw/convert-json-to-asn-toolcall "search" "{\"q\": \"asl\"}"))]
    (do
      (assert (string-contains? res ":tool \"search\"") "Must include tool name")
      (assert (string-contains? res ":args") "Must include args tag")
      true)))

(df test-format-browser-wire-payload [] -> Bool
  :d "Verifies formatting inference request payload for WebGPU"
  (let [(payload (bgw/format-browser-wire-payload "Hello model" (bgw/BrowserInferenceTarget:target-webgpu)))]
    (do
      (assert (string-contains? payload ":target") "Must specify target")
      (assert (string-contains? payload "target-webgpu") "Must specify webgpu variant")
      (assert (string-contains? payload "Hello model") "Must specify prompt")
      true)))

(df run-tests [] -> Bool
  :d "Executes all in-browser inference gateway tests"
  (do
    (assert (test-browser-think-quarantine) "test-browser-think-quarantine must pass")
    (assert (test-browser-esh-interception) "test-browser-esh-interception must pass")
    (assert (test-browser-clean-turn) "test-browser-clean-turn must pass")
    (assert (test-json-to-asn-toolcall-conversion) "test-json-to-asn-toolcall-conversion must pass")
    (assert (test-format-browser-wire-payload) "test-format-browser-wire-payload must pass")
    true))
