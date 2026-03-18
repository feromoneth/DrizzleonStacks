;; SIP-010: Standard Fungible Token Trait
(define-trait sip-010-trait
  (
    ;; Transfer
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))

    ;; Get token name
    (get-name () (response (string-ascii 32) uint))

    ;; Get token symbol
    (get-symbol () (response (string-ascii 32) uint))

    ;; Get number of decimals
    (get-decimals () (response uint uint))

    ;; Get balance of principal
    (get-balance (principal) (response uint uint))

    ;; Get total supply
    (get-total-supply () (response uint uint))

    ;; Get token URI
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)
