(module asl-gateway/browser-gateway
  :d "Pure ASL In-Browser (WebGPU/Wasm) & Local Model Inference Gateway: tri-channel demuxing, ESH interception, and bidirectional ASN <-> JSON tool calling."
  :x [BrowserInferenceTarget
      BrowserTurnVerdict
      target-to-string
      extract-browser-think-blocks
      detect-browser-esh-violation
      inspect-browser-turn
      convert-json-to-asn-toolcall
      format-browser-wire-payload]
  :i [(wire :a wire)])

(dfe BrowserInferenceTarget
  (:c target-webgpu [] "In-browser WebGPU execution (e.g. WebLLM, Transformers.js)")
  (:c target-wasm [] "In-browser WebAssembly CPU execution (e.g. ONNX Runtime Web)")
  (:c target-local-ollama [] "Local machine Ollama HTTP endpoint")
  (:c target-local-vllm [] "Local machine vLLM or llama.cpp endpoint"))

(dfs BrowserTurnVerdict
  (:f allowed Bool "True if completion satisfies all cognitive gateway invariants")
  (:f quarantined-think Str "Quarantined chain-of-thought scratchpad")
  (:f clean-output Str "Clean conversational UI text")
  (:f tool-calls (List Str) "Extracted executable tool call frames")
  (:f rejection-reason Str "Diagnostic rejection reason if flagged"))

(df extract-browser-think-blocks [(text Str)] -> (Pair Str Str)
  :d "Extracts <think>...</think> CoT reasoning blocks from the raw completion stream"
  (let [(open-tag "<think>")
        (close-tag "</think>")
        (idx-open (string-index-of text open-tag))]
    (mt idx-open
      ((none) (pair "" text))
      ((some o)
       (let [(after-open (option-or (string-slice text (+ o 7) (string-length text)) ""))
             (idx-close (string-index-of after-open close-tag))]
         (mt idx-close
           ((none) (pair (string-trim after-open) (option-or (string-slice text 0 o) "")))
           ((some c)
            (let [(think-content (option-or (string-slice after-open 0 c) ""))
                  (prefix (option-or (string-slice text 0 o) ""))
                  (suffix (option-or (string-slice after-open (+ c 8) (string-length after-open)) ""))
                  (remaining (string-trim (str prefix " " suffix)))]
              (pair (string-trim think-content) remaining)))))))))

(df detect-browser-esh-violation [(text Str)] -> Bool
  :d "Detects verbal execution simulation claims without verified execution proof"
  (let [(lower (string-to-lower text))]
    (or (string-contains? lower "all 5 tests pass")
        (or (string-contains? lower "all tests pass")
            (or (string-contains? lower "all tests passed")
                (or (string-contains? lower "verified all tests pass")
                    (or (string-contains? lower "gate passes cleanly")
                        (string-contains? lower "all assertions verified"))))))))

(df convert-json-to-asn-toolcall [(tool-name Str) (json-args-str Str)] -> Str
  :d "Converts incoming JSON tool calling payload into compact canonical ASN tool call"
  (str "(:call :tool \"" tool-name "\" :args " json-args-str ")"))

(df target-to-string [(target BrowserInferenceTarget)] -> Str
  :d "Converts BrowserInferenceTarget enum variant to wire string"
  (mt target
    ((target-webgpu) "target-webgpu")
    ((target-wasm) "target-wasm")
    ((target-local-ollama) "target-local-ollama")
    ((target-local-vllm) "target-local-vllm")))

(df format-browser-wire-payload [(prompt Str) (target BrowserInferenceTarget)] -> Str
  :d "Formats inference request payload for target browser or local engine"
  (str "(:inference-request :target \"" (target-to-string target) "\" :prompt \"" prompt "\")"))

(df inspect-browser-turn [(raw-text Str) (has-verified-exec Bool)] -> BrowserTurnVerdict
  :d "Executes full L7 cognitive gateway inspection for in-browser inference"
  (let [(demux-think (extract-browser-think-blocks raw-text))
        (think-part (pair-first demux-think))
        (remaining (pair-second demux-think))
        (demux-asn (wire/demux-raw-asn-turn remaining))
        (ui-part (pair-first demux-asn))
        (tool-part (pair-second demux-asn))
        (is-esh (and (detect-browser-esh-violation ui-part) (not has-verified-exec)))]
    (if is-esh
        (BrowserTurnVerdict
          :allowed false
          :quarantined-think think-part
          :clean-output "Action blocked by L7 Cognitive Gateway: verbal claim of test passage without verified execution receipt (ESH violation)."
          :tool-calls (list)
          :rejection-reason "Verbal self-declared execution without verified runtime proof (ESH violation)")
        (BrowserTurnVerdict
          :allowed true
          :quarantined-think think-part
          :clean-output ui-part
          :tool-calls tool-part
          :rejection-reason ""))))
