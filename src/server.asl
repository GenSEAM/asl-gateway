(module asl-gateway/server
  :d "Sovereign L7 Cognitive Gateway server pipeline: stream demuxing, CoT quarantine, verbal ESH interception, and tool routing."
  :x [GatewayChannel
      GatewayTurnVerdict
      extract-think-blocks
      detect-esh-violation
      inspect-completion-turn]
  :i [(wire :a wire)])

(dfe GatewayChannel
  (:c channel-ui [] "Channel A: direct conversational output")
  (:c channel-think [] "Channel B: quarantined CoT reasoning")
  (:c channel-tool [] "Channel C: structured tool execution frames"))

(dfs GatewayTurnVerdict
  (:f allowed Bool "True if completion satisfies all cognitive gateway invariants")
  (:f quarantined-think Str "Quarantined chain-of-thought scratchpad")
  (:f clean-output Str "Clean conversational and declarative ASN output for user")
  (:f tool-calls (List Str) "Extracted executable tool call frames")
  (:f rejection-reason Str "Diagnostic reason if inspection failed"))

(df extract-think-blocks [(text Str)] -> (Pair Str Str)
  :d "Separates <think>...</think> block from remaining conversational stream"
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

(df detect-esh-violation [(text Str)] -> Bool
  :d "Detects verbal execution simulation claims without verified execution proof"
  (let [(lower (string-to-lower text))]
    (or (string-contains? lower "all 5 tests pass")
        (or (string-contains? lower "all tests pass")
            (or (string-contains? lower "verified all tests pass")
                (or (string-contains? lower "100% tests pass")
                    (or (string-contains? lower "gate passes cleanly")
                        (string-contains? lower "all assertions verified"))))))))

(df inspect-completion-turn [(raw-text Str) (has-verified-exec Bool)] -> GatewayTurnVerdict
  :d "Executes full L7 cognitive gateway inspection on completion turn"
  (let [(demux-think (extract-think-blocks raw-text))
        (think-part (pair-first demux-think))
        (remaining (pair-second demux-think))
        (demux-asn (wire/demux-raw-asn-turn remaining))
        (ui-part (pair-first demux-asn))
        (tool-part (pair-second demux-asn))
        (is-esh (and (detect-esh-violation ui-part) (not has-verified-exec)))]
    (if is-esh
        (GatewayTurnVerdict
          :allowed false
          :quarantined-think think-part
          :clean-output "Action blocked by L7 Cognitive Gateway: verbal claim of test passage without verified execution receipt (ESH violation)."
          :tool-calls (list)
          :rejection-reason "Verbal self-declared execution without verified runtime proof (ESH violation)")
        (GatewayTurnVerdict
          :allowed true
          :quarantined-think think-part
          :clean-output ui-part
          :tool-calls tool-part
          :rejection-reason ""))))
