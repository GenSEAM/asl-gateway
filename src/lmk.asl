(module asl-gateway/lmk
  :d "Hierarchical LLM Models & Keys (LMK) resolution engine and dynamic runtime profile manager."
  :x [LmkKeySource
      LmkProfile
      LmkHierarchyInput
      make-lmk-profile
      mask-api-key
      resolve-lmk-profile
      format-lmk-profile-asn]
  :i [])

(dfe LmkKeySource
  (:c source-ui [] "Dynamic override from UI or request headers")
  (:c source-local [] "Resolved from local workspace .asl/gateway.asn")
  (:c source-global [] "Resolved from global user ~/.asl/gateway.asn")
  (:c source-env [] "Resolved from system environment variable")
  (:c source-fallback [] "Hardcoded default fallback"))

(dfs LmkProfile
  (:f provider Str "Provider name")
  (:f base-url Str "Provider endpoint base URL")
  (:f model-id Str "Active model identifier")
  (:f api-key Str "Resolved API key or secret token")
  (:f key-source LmkKeySource "Source of credentials")
  (:f max-tokens I64 "Token budget limit")
  (:f temperature F64 "Sampling temperature"))

(dfs LmkHierarchyInput
  (:f provider Str "Target provider name")
  (:f model-id Str "Target model identifier")
  (:f ui-api-key Str "Dynamic override API key from UI")
  (:f ui-base-url Str "Dynamic override base URL from UI")
  (:f local-api-key Str "API key from local workspace config")
  (:f local-base-url Str "Base URL from local workspace config")
  (:f global-api-key Str "API key from global user config")
  (:f global-base-url Str "Base URL from global user config")
  (:f env-api-key Str "API key from environment variable")
  (:f env-base-url Str "Base URL from environment variable"))

(df make-lmk-profile [(p Str) (url Str) (m Str) (k Str) (src LmkKeySource) (max-t I64) (temp F64)] -> LmkProfile
  :d "Constructs an LmkProfile record"
  (LmkProfile
    :provider p
    :base-url url
    :model-id m
    :api-key k
    :key-source src
    :max-tokens max-t
    :temperature temp))

(df mask-api-key [(key Str)] -> Str
  :d "Securely masks secret key preventing leakage in UI and telemetry logs"
  (let [(len (string-length key))]
    (if (<= len 8)
        "********"
        (let [(prefix (option-or (string-slice key 0 3) "sk-"))
              (suffix (option-or (string-slice key (- len 4) len) "****"))]
          (str prefix "..." suffix)))))

(df resolve-lmk-profile [(input LmkHierarchyInput)] -> LmkProfile
  :d "Resolves provider credentials and endpoints through the 4-tier hierarchy: UI > Local > Global > Env > Fallback"
  (let [(p (.-provider input))
        (m (.-model-id input))]
    (if (> (string-length (.-ui-api-key input)) 0)
        (let [(url (if (> (string-length (.-ui-base-url input)) 0) (.-ui-base-url input) "http://127.0.0.1:8765/v1"))]
          (make-lmk-profile p url m (.-ui-api-key input) (source-ui) 4096 0.2))
        (if (> (string-length (.-local-api-key input)) 0)
            (let [(url (if (> (string-length (.-local-base-url input)) 0) (.-local-base-url input) "http://127.0.0.1:8765/v1"))]
              (make-lmk-profile p url m (.-local-api-key input) (source-local) 4096 0.2))
            (if (> (string-length (.-global-api-key input)) 0)
                (let [(url (if (> (string-length (.-global-base-url input)) 0) (.-global-base-url input) "http://127.0.0.1:8765/v1"))]
                  (make-lmk-profile p url m (.-global-api-key input) (source-global) 4096 0.2))
                (if (> (string-length (.-env-api-key input)) 0)
                    (let [(url (if (> (string-length (.-env-base-url input)) 0) (.-env-base-url input) "http://127.0.0.1:8765/v1"))]
                      (make-lmk-profile p url m (.-env-api-key input) (source-env) 4096 0.2))
                    (make-lmk-profile p "http://127.0.0.1:8765/v1" m "" (source-fallback) 2048 0.2)))))))

(df format-lmk-profile-asn [(profile LmkProfile) (mask-key Bool)] -> Str
  :d "Serializes profile to canonical ASN representation"
  (let [(display-key (if mask-key (mask-api-key (.-api-key profile)) (.-api-key profile)))
        (src-str (mt (.-key-source profile)
                   ((source-ui) "ui-override")
                   ((source-local) "local-workspace")
                   ((source-global) "global-user")
                   ((source-env) "environment")
                   ((source-fallback) "fallback")))]
    (str "(:lmk-profile\n"
         "  :provider \"" (.-provider profile) "\"\n"
         "  :base-url \"" (.-base-url profile) "\"\n"
         "  :model-id \"" (.-model-id profile) "\"\n"
         "  :api-key \"" display-key "\"\n"
         "  :source \"" src-str "\"\n"
         "  :max-tokens " (string-from-int64 (.-max-tokens profile)) "\n"
         "  :temperature " (string-from-float64 (.-temperature profile)) "\n"
         ")")))
