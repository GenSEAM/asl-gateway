(module asl-gateway/tests/wire-test
  :d "Unit tests for ASN wire protocol headers and tool-call vs declarative ASN disambiguation."
  :x [test-wire-headers
      test-is-tool-call
      test-is-declarative-asn
      test-extract-tool-name
      test-format-tool-call-frame
      test-demux-raw-asn-turn
      run-tests]
  :i [(wire :a wire)])

(df test-wire-headers [] -> Bool
  :d "Verifies protocol negotiation headers."
  (let [(headers (wire/format-wire-headers))]
    (do
      (assert (= (list-length headers) 3) "Must have 3 wire protocol headers")
      (assert (= (option-unwrap (list-head headers)) "X-ASL-Wire-Protocol: asn/1.0") "First header must be ASN wire protocol")
      true)))

(df test-is-tool-call [] -> Bool
  :d "Verifies imperative tool call S-expressions are detected."
  (do
    (assert (wire/is-tool-call? "(:call :tool \"bash\" :cmd \"ls\")") "(:call :tool ...) must be a tool call")
    (assert (wire/is-tool-call? "(call :tool \"eval\" :expr \"(+ 1 2)\")") "(call :tool ...) must be a tool call")
    (assert (wire/is-tool-call? "(:call \"read\" :file \"foo.txt\")") "(:call \"...\" ...) must be a tool call")
    (assert (wire/is-tool-call? "(:tool-call :name \"git\")") "(:tool-call ...) must be a tool call")
    (assert (not (wire/is-tool-call? "(:struct Foo (:f x I64))")) "(:struct ...) must not be a tool call")
    (assert (not (wire/is-tool-call? "Hello, here is the answer.")) "Conversational text must not be a tool call")
    true))

(df test-is-declarative-asn [] -> Bool
  :d "Verifies declarative AST and data structures are correctly identified."
  (do
    (assert (wire/is-declarative-asn? "(:struct User (:f name Str))") "(:struct ...) must be declarative ASN")
    (assert (wire/is-declarative-asn? "(:ast :node \"Program\")") "(:ast ...) must be declarative ASN")
    (assert (wire/is-declarative-asn? "(:code :lang \"asl\" \"(df foo [] -> I64 42)\")") "(:code ...) must be declarative ASN")
    (assert (wire/is-declarative-asn? "(:config :port 8080)") "(:config ...) must be declarative ASN")
    (assert (wire/is-declarative-asn? "(module my-mod :d \"desc\")") "(module ...) must be declarative ASN")
    (assert (not (wire/is-declarative-asn? "(:call :tool \"bash\")")) "Tool call must not be declarative ASN")
    true))

(df test-extract-tool-name [] -> Bool
  :d "Verifies tool name extraction."
  (let [(name1 (wire/extract-tool-name "(:call :tool \"bash\" :cmd \"ls\")"))
        (name2 (wire/extract-tool-name "(:call :tool \"read_file\" :path \"a.txt\")"))
        (name3 (wire/extract-tool-name "non-tool-call"))]
    (do
      (assert (= name1 "bash") "Tool name must be bash")
      (assert (= name2 "read_file") "Tool name must be read_file")
      (assert (= name3 "tool") "Fallback tool name must be tool")
      true)))

(df test-format-tool-call-frame [] -> Bool
  :d "Verifies tool call frame formatting."
  (let [(frame (wire/format-tool-call-frame "search" ":query \"paxos\""))]
    (do
      (assert (= frame "(:call :tool \"search\" :query \"paxos\")") "Frame must match canonical S-expression")
      (assert (not (string-contains? frame "error")) "Frame must not contain error")
      true)))

(df test-demux-raw-asn-turn [] -> Bool
  :d "Verifies demuxing raw turn into UI and tool frames."
  (let [(turn-tool (wire/demux-raw-asn-turn "(:call :tool \"ls\" :path \".\")"))
        (turn-text (wire/demux-raw-asn-turn "(:struct Result (:f ok Bool))"))
        (ui-tool (pair-first turn-tool))
        (tools-tool (pair-second turn-tool))
        (ui-text (pair-first turn-text))
        (tools-text (pair-second turn-text))]
    (do
      (assert (= ui-tool "") "UI text for tool call must be empty")
      (assert (= (list-length tools-tool) 1) "Must extract 1 tool call frame")
      (assert (= ui-text "(:struct Result (:f ok Bool))") "Declarative ASN must remain in UI text")
      (assert (= (list-length tools-text) 0) "No tool calls extracted from declarative ASN")
      true)))

(df run-tests [] -> Bool
  :d "Runs all wire protocol tests."
  (and (test-wire-headers)
       (and (test-is-tool-call)
            (and (test-is-declarative-asn)
                 (and (test-extract-tool-name)
                      (and (test-format-tool-call-frame)
                           (test-demux-raw-asn-turn)))))))
