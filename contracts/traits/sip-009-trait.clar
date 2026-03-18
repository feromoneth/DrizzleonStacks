;; SIP-009: Standard NFT Trait
(define-trait sip-009-trait
  (
    ;; Last token ID
    (get-last-token-id () (response uint uint))

    ;; Token URI
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))

    ;; Owner
    (get-owner (uint) (response (optional principal) uint))

    ;; Transfer
    (transfer (uint principal principal) (response bool uint))
  )
)
