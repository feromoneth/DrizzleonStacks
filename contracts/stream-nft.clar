;; stream-nft.clar
;; SIP-009 compliant NFT representing a recipient's claim on a live stream.
;; Minted by stream-core at stream creation. Transfers update recipient in stream-core.

;; ============================================================
;; Traits
;; ============================================================

(impl-trait .sip-009-trait.sip-009-trait)

;; ============================================================
;; Constants
;; ============================================================

(define-constant CONTRACT_OWNER tx-sender)

(define-constant ERR_NOT_AUTHORIZED (err u4001))
(define-constant ERR_NOT_FOUND (err u4002))
(define-constant ERR_ALREADY_MINTED (err u4003))
(define-constant ERR_WRONG_OWNER (err u4004))
(define-constant ERR_NOT_CORE_CONTRACT (err u4005))

;; ============================================================
;; NFT Definition
;; ============================================================

(define-non-fungible-token stream-position uint)

;; ============================================================
;; Data
;; ============================================================

(define-data-var token-counter uint u0)

;; Map NFT id → stream-id for reverse lookup
(define-map nft-stream-map uint uint)

;; Map stream-id → NFT id
(define-map stream-nft-map uint uint)

;; Map NFT id → optional token URI
(define-map token-uris uint (string-ascii 256))

;; ============================================================
;; SIP-009 Public Functions
;; ============================================================

;; Transfer NFT. Only the current owner (or approved operator) can transfer.
;; After transfer, notifies stream-core to update the stream's recipient.
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    ;; sender must be tx-sender
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    ;; sender must own the token
    (asserts! (is-eq (some sender) (nft-get-owner? stream-position token-id)) ERR_WRONG_OWNER)
    ;; Perform NFT transfer
    (try! (nft-transfer? stream-position token-id sender recipient))
    ;; Notify stream-core about the new recipient
    (let
      (
        (stream-id (unwrap! (map-get? nft-stream-map token-id) ERR_NOT_FOUND))
      )
      (try! (contract-call? .stream-core update-recipient stream-id recipient))
    )
    (ok true)
  )
)

(define-read-only (get-last-token-id)
  (ok (var-get token-counter))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (map-get? token-uris token-id))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? stream-position token-id))
)

;; ============================================================
;; Mint Function — Called by stream-core only
;; ============================================================

;; Mint a new stream position NFT to the recipient.
;; Returns the new token-id.
(define-public (mint-stream-nft (recipient principal) (stream-id uint))
  (let
    (
      (token-id (+ (var-get token-counter) u1))
    )
    ;; Only stream-core can mint
    (asserts! (is-eq contract-caller .stream-core) ERR_NOT_CORE_CONTRACT)
    ;; Mint the NFT
    (try! (nft-mint? stream-position token-id recipient))
    ;; Store mappings
    (map-set nft-stream-map token-id stream-id)
    (map-set stream-nft-map stream-id token-id)
    ;; Increment counter
    (var-set token-counter token-id)
    (ok token-id)
  )
)

;; ============================================================
;; Read-Only Helpers
;; ============================================================

;; Get stream-id from NFT id
(define-read-only (get-stream-id-for-nft (token-id uint))
  (map-get? nft-stream-map token-id)
)

;; Get NFT id from stream-id
(define-read-only (get-nft-for-stream (stream-id uint))
  (map-get? stream-nft-map stream-id)
)

;; Set token URI — only deployer can set
(define-public (set-token-uri (token-id uint) (uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set token-uris token-id uri)
    (ok true)
  )
)
