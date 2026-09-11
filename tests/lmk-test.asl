(module asl-gateway/tests/lmk-test
  :d "Unit tests for hierarchical LMK resolution, secret masking, and profile serialization."
  :x [test-ui-override-precedence
      test-local-workspace-precedence
      test-global-user-precedence
      test-env-fallback
      test-mask-api-key
      test-format-lmk-profile-asn
      run-tests]
  :i [(lmk :a lmk)])

(df test-ui-override-precedence [] -> Bool
  :d "Verifies dynamic UI override takes highest precedence over all config levels."
  (let [(inp (lmk/LmkHierarchyInput
               :provider "anthropic"
               :model-id "claude-3-7-sonnet"
               :ui-api-key "sk-ant-ui-dynamic-override-999"
               :ui-base-url "https://api.anthropic.com/v1"
               :local-api-key "sk-ant-local-workspace-888"
               :local-base-url "https://local.anthropic.com/v1"
               :global-api-key "sk-ant-global-user-777"
               :global-base-url "https://global.anthropic.com/v1"
               :env-api-key "sk-ant-env-var-666"
               :env-base-url "https://env.anthropic.com/v1"))
        (prof (lmk/resolve-lmk-profile inp))]
    (do
      (assert (= (.-api-key prof) "sk-ant-ui-dynamic-override-999") "API key must be UI dynamic override")
      (assert (= (.-base-url prof) "https://api.anthropic.com/v1") "Base URL must be UI override URL")
      (mt (.-key-source prof)
        ((source-ui) true)
        ((default) (assert false "Source must be source-ui")))
      true)))

(df test-local-workspace-precedence [] -> Bool
  :d "Verifies local workspace config takes precedence when UI override is empty."
  (let [(inp (lmk/LmkHierarchyInput
               :provider "openai"
               :model-id "gpt-4o"
               :ui-api-key ""
               :ui-base-url ""
               :local-api-key "sk-proj-local-workspace-888"
               :local-base-url "https://api.openai.com/v1"
               :global-api-key "sk-proj-global-user-777"
               :global-base-url "https://global.openai.com/v1"
               :env-api-key "sk-proj-env-var-666"
               :env-base-url "https://env.openai.com/v1"))
        (prof (lmk/resolve-lmk-profile inp))]
    (do
      (assert (= (.-api-key prof) "sk-proj-local-workspace-888") "API key must be local workspace key")
      (mt (.-key-source prof)
        ((source-local) true)
        ((default) (assert false "Source must be source-local")))
      true)))

(df test-global-user-precedence [] -> Bool
  :d "Verifies global user config takes precedence when local is empty."
  (let [(inp (lmk/LmkHierarchyInput
               :provider "gemini"
               :model-id "gemini-2.5-flash"
               :ui-api-key ""
               :ui-base-url ""
               :local-api-key ""
               :local-base-url ""
               :global-api-key "AIzaSy-global-user-777"
               :global-base-url "https://generativelanguage.googleapis.com/v1"
               :env-api-key "AIzaSy-env-var-666"
               :env-base-url "https://env.googleapis.com/v1"))
        (prof (lmk/resolve-lmk-profile inp))]
    (do
      (assert (= (.-api-key prof) "AIzaSy-global-user-777") "API key must be global user key")
      (mt (.-key-source prof)
        ((source-global) true)
        ((default) (assert false "Source must be source-global")))
      true)))

(df test-env-fallback [] -> Bool
  :d "Verifies environment variable fallback when all config files are empty."
  (let [(inp (lmk/LmkHierarchyInput
               :provider "ollama"
               :model-id "gemma-4-31b-it"
               :ui-api-key ""
               :ui-base-url ""
               :local-api-key ""
               :local-base-url ""
               :global-api-key ""
               :global-base-url ""
               :env-api-key "env-token-xyz"
               :env-base-url "http://localhost:11434/v1"))
        (prof (lmk/resolve-lmk-profile inp))]
    (do
      (assert (= (.-api-key prof) "env-token-xyz") "API key must be env token")
      (assert (= (.-base-url prof) "http://localhost:11434/v1") "Base URL must be env URL")
      (mt (.-key-source prof)
        ((source-env) true)
        ((default) (assert false "Source must be source-env")))
      true)))

(df test-mask-api-key [] -> Bool
  :d "Verifies secret keys are securely masked."
  (let [(short-key (lmk/mask-api-key "12345"))
        (long-key (lmk/mask-api-key "sk-ant-api03-abcdef1234567890"))]
    (do
      (assert (= short-key "********") "Short key must be masked with 8 asterisks")
      (assert (string-starts-with? long-key "sk-...") "Long key must start with prefix and ellipsis")
      (assert (string-ends-with? long-key "7890") "Long key must end with last 4 chars")
      true)))

(df test-format-lmk-profile-asn [] -> Bool
  :d "Verifies ASN profile serialization."
  (let [(p (lmk/make-lmk-profile "openai" "https://api.openai.com/v1" "gpt-4o" "sk-1234567890abcdef" (lmk/source-ui) 4096 0.2))
        (masked-asn (lmk/format-lmk-profile-asn p true))
        (unmasked-asn (lmk/format-lmk-profile-asn p false))]
    (do
      (assert (string-starts-with? masked-asn "(:lmk-profile") "ASN must start with :lmk-profile")
      (assert (string-contains? masked-asn ":provider \"openai\"") "ASN must contain provider")
      (assert (string-contains? masked-asn ":source \"ui-override\"") "ASN must contain source")
      (assert (string-contains? masked-asn ":api-key \"sk-...cdef\"") "Masked ASN must hide secret")
      (assert (string-contains? unmasked-asn ":api-key \"sk-1234567890abcdef\"") "Unmasked ASN must contain raw key")
      true)))

(df run-tests [] -> Bool
  :d "Runs all LMK tests."
  (and (test-ui-override-precedence)
       (and (test-local-workspace-precedence)
            (and (test-global-user-precedence)
                 (and (test-env-fallback)
                      (and (test-mask-api-key)
                           (test-format-lmk-profile-asn)))))))
