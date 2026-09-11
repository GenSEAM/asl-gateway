(module asl-gateway/wire
  :d "Pure ASN Wire Protocol negotiation, header formatting, and imperative vs declarative tool-call disambiguation."
  :x [format-wire-headers
      is-tool-call?
      is-declarative-asn?
      extract-tool-name
      format-tool-call-frame
      demux-raw-asn-turn]
  :i [])

(df format-wire-headers [] -> (List Str)
  :d "Returns canonical ASN wire protocol negotiation headers"
  (list "X-ASL-Wire-Protocol: asn/1.0"
        "X-Tool-Call-Dialect: asn-sexpr"
        "Accept: application/asn+sexpr, application/json"))

(df is-tool-call? [(text Str)] -> Bool
  :d "Determines if S-expression is an imperative tool call rather than declarative data"
  (let [(trimmed (string-trim text))]
    (or (string-starts-with? trimmed "(:call :tool")
        (or (string-starts-with? trimmed "(call :tool")
            (or (string-starts-with? trimmed "(:call \"")
                (or (string-starts-with? trimmed "(call \"")
                    (string-starts-with? trimmed "(:tool-call")))))))

(df is-declarative-asn? [(text Str)] -> Bool
  :d "Determines if S-expression is declarative AST or data structure to preserve in UI stream"
  (let [(trimmed (string-trim text))]
    (or (string-starts-with? trimmed "(:struct")
        (or (string-starts-with? trimmed "(:ast")
            (or (string-starts-with? trimmed "(:code")
                (or (string-starts-with? trimmed "(:config")
                    (or (string-starts-with? trimmed "(:grammar")
                        (or (string-starts-with? trimmed "(:package")
                            (or (string-starts-with? trimmed "(module")
                                (string-starts-with? trimmed "(:model-profile"))))))))))

(df extract-tool-name [(text Str)] -> Str
  :d "Extracts tool name from imperative tool call S-expression"
  (let [(trimmed (string-trim text))
        (prefix "(:call :tool \"")]
    (if (string-starts-with? trimmed prefix)
        (let [(after (option-or (string-slice trimmed (string-length prefix) (string-length trimmed)) ""))
              (quote-idx (string-index-of after "\""))]
          (mt quote-idx
            ((some q) (option-or (string-slice after 0 q) "tool"))
            ((none) "tool")))
        "tool")))

(df format-tool-call-frame [(tool-name Str) (args-asn Str)] -> Str
  :d "Formats tool call into standard compact ASN S-expression"
  (str "(:call :tool \"" tool-name "\" " args-asn ")"))

(df demux-raw-asn-turn [(text Str)] -> (Pair Str (List Str))
  :d "Demuxes turn into UI text and extracted tool call frames"
  (let [(trimmed (string-trim text))]
    (if (is-tool-call? trimmed)
        (pair "" (list trimmed))
        (pair text (list)))))
