;; mock-token.clar
;; A minimal SIP-010 compliant token for testing purposes only.

(impl-trait .sip-010-trait.sip-010-trait)

(define-fungible-token mock-token)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u5001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u5002))

;; SIP-010 Functions
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender from) ERR_UNAUTHORIZED)
    (ft-transfer? mock-token amount from to)
  )
)

(define-read-only (get-name)
  (ok "Mock Token")
)

(define-read-only (get-symbol)
  (ok "MOCK")
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance mock-token account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply mock-token))
)

(define-read-only (get-token-uri)
  (ok none)
)

;; Mint — for testing only
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ft-mint? mock-token amount recipient)
  )
)
